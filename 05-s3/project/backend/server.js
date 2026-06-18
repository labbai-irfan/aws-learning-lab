// server.js — Secure file upload API using S3 pre-signed URLs (AWS SDK v3, ESM)
// The browser uploads DIRECTLY to S3; this server only validates and signs.
// AWS credentials NEVER reach the browser.
import 'dotenv/config';
import express from 'express';
import cors from 'cors';
import { randomUUID } from 'crypto';
import { S3Client, PutObjectCommand, GetObjectCommand, HeadObjectCommand } from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';

const PORT = process.env.PORT || 5000;
const REGION = process.env.AWS_REGION || 'ap-south-1';
const BUCKET = process.env.S3_BUCKET;
const MAX_BYTES = (parseInt(process.env.MAX_UPLOAD_MB || '10', 10)) * 1024 * 1024;
const ALLOWED_TYPES = (process.env.ALLOWED_TYPES || 'image/png,image/jpeg,application/pdf')
  .split(',').map((s) => s.trim());
const ALLOWED_ORIGIN = process.env.ALLOWED_ORIGIN || 'http://localhost:5173';

if (!BUCKET) {
  console.error('Missing S3_BUCKET env var'); process.exit(1);
}

// The SDK auto-discovers credentials: env vars (local dev) OR the IAM role (EC2/Lambda).
const s3 = new S3Client({ region: REGION });

const app = express();
app.use(express.json());
app.use(cors({ origin: ALLOWED_ORIGIN }));

// Health check
app.get('/api/health', (req, res) => res.json({ status: 'ok' }));

// 1) Issue a pre-signed PUT URL after validating the request.
app.post('/api/uploads/presign', async (req, res) => {
  try {
    const { filename, contentType, size } = req.body || {};

    // --- server-side validation (defense before signing) ---
    if (!filename || !contentType) {
      return res.status(400).json({ error: 'filename and contentType are required' });
    }
    if (!ALLOWED_TYPES.includes(contentType)) {
      return res.status(415).json({ error: `type not allowed. Allowed: ${ALLOWED_TYPES.join(', ')}` });
    }
    if (typeof size === 'number' && size > MAX_BYTES) {
      return res.status(413).json({ error: `file too large. Max ${MAX_BYTES / 1024 / 1024} MB` });
    }

    // Safe, collision-free key. In a real app, prefix with the authenticated user id.
    const safeName = filename.replace(/[^a-zA-Z0-9._-]/g, '_');
    const key = `uploads/${randomUUID()}-${safeName}`;

    const command = new PutObjectCommand({
      Bucket: BUCKET,
      Key: key,
      ContentType: contentType // browser MUST send this exact Content-Type on PUT
    });
    const uploadUrl = await getSignedUrl(s3, command, { expiresIn: 300 }); // 5 min

    res.json({ uploadUrl, key });
  } catch (err) {
    console.error('presign PUT failed:', err);
    res.status(500).json({ error: 'could not create upload URL' });
  }
});

// 2) Issue a pre-signed GET URL to view/download a private object.
app.get('/api/uploads/url', async (req, res) => {
  try {
    const key = req.query.key;
    if (!key || !String(key).startsWith('uploads/')) {
      return res.status(400).json({ error: 'valid key required' });
    }
    // confirm it exists (and is in our prefix) before signing
    await s3.send(new HeadObjectCommand({ Bucket: BUCKET, Key: key }));
    const downloadUrl = await getSignedUrl(
      s3, new GetObjectCommand({ Bucket: BUCKET, Key: key }), { expiresIn: 120 }
    );
    res.json({ downloadUrl });
  } catch (err) {
    if (err.name === 'NotFound') return res.status(404).json({ error: 'object not found' });
    console.error('presign GET failed:', err);
    res.status(500).json({ error: 'could not create download URL' });
  }
});

app.listen(PORT, () => console.log(`Secure upload API on http://localhost:${PORT} (bucket: ${BUCKET})`));
