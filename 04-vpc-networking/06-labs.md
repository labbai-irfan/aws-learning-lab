# Module 3 — Hands-On Labs

Build a real VPC from nothing, step by step. Each lab states a **goal**, the **steps** (Console + CLI), and a **verification**. Do them in order — later labs reuse earlier resources.

> 💰 **Cost warning:** NAT Gateways cost ~$0.045/hr **+ data** and Elastic IPs cost when idle. Do the NAT labs in one sitting and run **Lab 9 (teardown)** when done. Most other resources (VPC, subnets, route tables, IGW, SGs, NACLs, gateway endpoints) are **free**.

**Region used in examples:** `ap-south-1`. Replace IDs (`vpc-xxxx`) with your own as you go.

---

## Lab 0 — Setup & sanity check

```bash
aws --version                      # need AWS CLI v2
aws sts get-caller-identity        # confirm you're authenticated
aws configure set region ap-south-1
```
✅ You see your account ID and a region.

---

## Lab 1 — Create a custom VPC

**Goal:** A `/16` VPC with DNS enabled.

```bash
# Create the VPC
VPC_ID=$(aws ec2 create-vpc --cidr-block 10.0.0.0/16 \
  --tag-specifications 'ResourceType=vpc,Tags=[{Key=Name,Value=lab-vpc}]' \
  --query 'Vpc.VpcId' --output text)
echo "VPC = $VPC_ID"

# Enable DNS hostnames + support
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-hostnames
aws ec2 modify-vpc-attribute --vpc-id $VPC_ID --enable-dns-support
```
**Verify:**
```bash
aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].{CIDR:CidrBlock,State:State}'
```
✅ State = `available`, CIDR = `10.0.0.0/16`.

---

## Lab 2 — Create public + private subnets across 2 AZs

**Goal:** 4 subnets (1 public + 1 private in each of 2 AZs).

```bash
# AZ-a public + private
PUB_A=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.1.0/24 \
  --availability-zone ap-south-1a --query 'Subnet.SubnetId' --output text \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-1a}]')
PRIV_A=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.2.0/24 \
  --availability-zone ap-south-1a --query 'Subnet.SubnetId' --output text \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-1a}]')

# AZ-b public + private
PUB_B=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.11.0/24 \
  --availability-zone ap-south-1b --query 'Subnet.SubnetId' --output text \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=public-1b}]')
PRIV_B=$(aws ec2 create-subnet --vpc-id $VPC_ID --cidr-block 10.0.12.0/24 \
  --availability-zone ap-south-1b --query 'Subnet.SubnetId' --output text \
  --tag-specifications 'ResourceType=subnet,Tags=[{Key=Name,Value=private-1b}]')

# Make the public subnets auto-assign public IPs
aws ec2 modify-subnet-attribute --subnet-id $PUB_A --map-public-ip-on-launch
aws ec2 modify-subnet-attribute --subnet-id $PUB_B --map-public-ip-on-launch
```
**Verify:**
```bash
aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" \
  --query 'Subnets[].{Name:Tags[0].Value,AZ:AvailabilityZone,CIDR:CidrBlock}' --output table
```
✅ 4 subnets across two AZs.

---

## Lab 3 — Internet Gateway + public route table

**Goal:** Make the public subnets actually public.

```bash
# Create + attach IGW
IGW_ID=$(aws ec2 create-internet-gateway --query 'InternetGateway.InternetGatewayId' --output text)
aws ec2 attach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID

# Public route table
PUB_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PUB_RT \
  --destination-cidr-block 0.0.0.0/0 --gateway-id $IGW_ID

# Associate the public subnets
aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB_A
aws ec2 associate-route-table --route-table-id $PUB_RT --subnet-id $PUB_B
```
**Verify:**
```bash
aws ec2 describe-route-tables --route-table-ids $PUB_RT \
  --query 'RouteTables[0].Routes'
```
✅ You see `0.0.0.0/0 → igw-…`.

**Test it end-to-end:** launch a tiny instance in `PUB_A` with a key pair + an SG allowing your IP on 22, then SSH in. If you can reach it, public routing works.

---

## Lab 4 — NAT Gateway + private route table

**Goal:** Let private subnets reach OUT to the internet.

```bash
# Allocate an Elastic IP for the NAT
EIP_ALLOC=$(aws ec2 allocate-address --domain vpc --query 'AllocationId' --output text)

# Create NAT GW in a PUBLIC subnet
NAT_ID=$(aws ec2 create-nat-gateway --subnet-id $PUB_A \
  --allocation-id $EIP_ALLOC --query 'NatGateway.NatGatewayId' --output text)

# Wait until available (NAT takes ~1-2 min)
aws ec2 wait nat-gateway-available --nat-gateway-ids $NAT_ID

# Private route table → NAT
PRIV_RT=$(aws ec2 create-route-table --vpc-id $VPC_ID --query 'RouteTable.RouteTableId' --output text)
aws ec2 create-route --route-table-id $PRIV_RT \
  --destination-cidr-block 0.0.0.0/0 --nat-gateway-id $NAT_ID
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV_A
aws ec2 associate-route-table --route-table-id $PRIV_RT --subnet-id $PRIV_B
```
**Verify:** launch an instance in `PRIV_A` (no public IP), connect via SSM Session Manager, then:
```bash
curl -s https://checkip.amazonaws.com   # should return the NAT's Elastic IP
ping -c2 8.8.8.8                         # should succeed
```
✅ Outbound works; the instance has no public IP and cannot be reached inbound.

---

## Lab 5 — Security Groups (the chaining pattern)

**Goal:** Build the web → app → db SG chain.

```bash
# SG for the load balancer (open to world)
SG_WEB=$(aws ec2 create-security-group --vpc-id $VPC_ID \
  --group-name sg-web --description "ALB" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_WEB \
  --protocol tcp --port 443 --cidr 0.0.0.0/0

# SG for the app (only from the web SG)
SG_APP=$(aws ec2 create-security-group --vpc-id $VPC_ID \
  --group-name sg-app --description "App" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_APP \
  --protocol tcp --port 8080 --source-group $SG_WEB

# SG for the DB (only from the app SG)
SG_DB=$(aws ec2 create-security-group --vpc-id $VPC_ID \
  --group-name sg-db --description "DB" --query 'GroupId' --output text)
aws ec2 authorize-security-group-ingress --group-id $SG_DB \
  --protocol tcp --port 3306 --source-group $SG_APP
```
**Verify:**
```bash
aws ec2 describe-security-groups --group-ids $SG_DB \
  --query 'SecurityGroups[0].IpPermissions'
```
✅ `sg-db` allows 3306 **only from `sg-app`** (a UserIdGroupPair, not a CIDR). This is defense in depth.

---

## Lab 6 — NACL (and proving "stateless")

**Goal:** See why stateless rules bite people.

```bash
# Create a custom NACL for the public subnet
NACL_ID=$(aws ec2 create-network-acl --vpc-id $VPC_ID --query 'NetworkAcl.NetworkAclId' --output text)

# Allow inbound HTTPS only (deliberately FORGET the return rule first)
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 100 \
  --protocol tcp --port-range From=443,To=443 --cidr-block 0.0.0.0/0 --rule-action allow --ingress

# Associate it with the public subnet's association id (find it):
ASSOC=$(aws ec2 describe-network-acls --filters "Name=association.subnet-id,Values=$PUB_A" \
  --query 'NetworkAcls[0].Associations[?SubnetId==`'$PUB_A'`].NetworkAclAssociationId' --output text)
aws ec2 replace-network-acl-association --association-id $ASSOC --network-acl-id $NACL_ID
```
🔎 **Observe:** outbound replies are now **blocked** because there's no outbound rule. Fix it:
```bash
# Allow outbound ephemeral ports (the RETURN traffic)
aws ec2 create-network-acl-entry --network-acl-id $NACL_ID --rule-number 100 \
  --protocol tcp --port-range From=1024,To=65535 --cidr-block 0.0.0.0/0 --rule-action allow --egress
```
✅ **Lesson learned:** NACLs are stateless — every allow needs a matching return-direction allow. (Then re-associate the default NACL to avoid surprises in later labs.)

---

## Lab 7 — S3 Gateway Endpoint (free private access)

**Goal:** Reach S3 from a private instance without NAT.

```bash
aws ec2 create-vpc-endpoint --vpc-id $VPC_ID \
  --service-name com.amazonaws.ap-south-1.s3 \
  --route-table-ids $PRIV_RT \
  --vpc-endpoint-type Gateway
```
**Verify:** from the private instance:
```bash
aws s3 ls         # works, and traffic never leaves the AWS backbone
```
✅ Check the private route table — there's now a managed prefix-list route (`pl-… → vpce-…`). 💰 This is free and removes S3 traffic from your NAT bill.

---

## Lab 8 — VPC Peering (connect two VPCs)

**Goal:** Privately connect `lab-vpc` to a second VPC.

```bash
# Second VPC with a NON-overlapping CIDR
VPC2=$(aws ec2 create-vpc --cidr-block 172.16.0.0/16 --query 'Vpc.VpcId' --output text)

# Request + accept the peering
PCX=$(aws ec2 create-vpc-peering-connection \
  --vpc-id $VPC_ID --peer-vpc-id $VPC2 \
  --query 'VpcPeeringConnection.VpcPeeringConnectionId' --output text)
aws ec2 accept-vpc-peering-connection --vpc-peering-connection-id $PCX

# Add routes on BOTH sides
aws ec2 create-route --route-table-id $PRIV_RT \
  --destination-cidr-block 172.16.0.0/16 --vpc-peering-connection-id $PCX
# (and a route 10.0.0.0/16 → $PCX on VPC2's route table)
```
**Verify:** an instance in each VPC can ping the other's **private IP**.
✅ Remember: routes on **both** sides + SGs allowing the peer CIDR. Peering is **not transitive**.

---

## Lab 9 — Teardown (stop the billing!) 🧹

Delete in reverse dependency order:
```bash
# 1. Delete NAT GW + release EIP (biggest cost)
aws ec2 delete-nat-gateway --nat-gateway-id $NAT_ID
aws ec2 wait nat-gateway-deleted --nat-gateway-ids $NAT_ID
aws ec2 release-address --allocation-id $EIP_ALLOC

# 2. Delete peering, endpoints
aws ec2 delete-vpc-peering-connection --vpc-peering-connection-id $PCX
# aws ec2 delete-vpc-endpoints --vpc-endpoint-ids vpce-xxxx

# 3. Terminate any EC2 instances you launched, then:
# 4. Detach + delete IGW
aws ec2 detach-internet-gateway --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
aws ec2 delete-internet-gateway --internet-gateway-id $IGW_ID

# 5. Delete subnets, custom route tables, SGs, custom NACLs
# 6. Finally delete the VPC(s)
aws ec2 delete-vpc --vpc-id $VPC_ID
aws ec2 delete-vpc --vpc-id $VPC2
```
✅ **Verify in the console** that no NAT Gateways or unattached Elastic IPs remain — those are what generate surprise charges.

---

## 🎓 Lab challenges (no hand-holding)

1. **Multi-AZ NAT:** add a second NAT GW in `PUB_B` and route `PRIV_B` to it. Why is this better than one shared NAT?
2. **Bastion-less access:** delete all port-22 rules and connect to a private instance using **SSM Session Manager** + interface endpoints (`ssm`, `ssmmessages`, `ec2messages`).
3. **Flow Logs:** enable **VPC Flow Logs** to CloudWatch, generate some traffic, and find an ACCEPT and a REJECT record.
4. **Full 3-tier:** combine Labs 1–7 into a working ALB → app → RDS stack and load the app in a browser.
5. **Break & fix:** intentionally point an app subnet's `0.0.0.0/0` at the IGW instead of NAT (with no public IP) and explain why outbound fails.

**Next:** [07-100-mcqs.md](07-100-mcqs.md).
