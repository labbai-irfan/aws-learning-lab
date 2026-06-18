import { useState } from 'react';

// The API base; the API issues pre-signed URLs. The browser uploads DIRECTLY to S3.
const API = import.meta.env.VITE_API_URL || 'http://localhost:5000';

export default function App() {
  const [file, setFile] = useState(null);
  const [status, setStatus] = useState('');
  const [progress, setProgress] = useState(0);
  const [downloadUrl, setDownloadUrl] = useState('');

  const upload = async (e) => {
    e.preventDefault();
    if (!file) return;
    setStatus('Requesting upload URL...');
    setDownloadUrl('');
    setProgress(0);

    try {
      // 1) Ask the server for a pre-signed PUT URL (server validates type/size)
      const presignRes = await fetch(`${API}/api/uploads/presign`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: file.name, contentType: file.type, size: file.size })
      });
      if (!presignRes.ok) {
        const { error } = await presignRes.json().catch(() => ({ error: 'presign failed' }));
        throw new Error(error);
      }
      const { uploadUrl, key } = await presignRes.json();

      // 2) PUT the file bytes DIRECTLY to S3 (XHR so we can show progress)
      setStatus('Uploading directly to S3...');
      await putWithProgress(uploadUrl, file, setProgress);

      // 3) Get a pre-signed GET URL to preview/download (bucket stays private)
      setStatus('Upload complete. Fetching download link...');
      const urlRes = await fetch(`${API}/api/uploads/url?key=${encodeURIComponent(key)}`);
      const { downloadUrl } = await urlRes.json();
      setDownloadUrl(downloadUrl);
      setStatus(`Done. Stored as ${key}`);
    } catch (err) {
      setStatus(`Error: ${err.message}`);
    }
  };

  return (
    <div style={{ maxWidth: 560, margin: '40px auto', fontFamily: 'system-ui, sans-serif' }}>
      <h1>🔒 Secure S3 Upload</h1>
      <p style={{ color: '#666' }}>
        Browser → pre-signed URL → <b>direct to private S3</b>. The server never sees the bytes;
        AWS keys never reach the browser.
      </p>

      <form onSubmit={upload} style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
        <input type="file" onChange={(e) => setFile(e.target.files[0])} />
        <button type="submit" disabled={!file}>Upload</button>
      </form>

      {progress > 0 && (
        <div style={{ marginTop: 16 }}>
          <div style={{ background: '#eee', borderRadius: 4, overflow: 'hidden' }}>
            <div style={{ width: `${progress}%`, background: '#2d8cff', height: 10 }} />
          </div>
          <small>{progress}%</small>
        </div>
      )}

      {status && <p style={{ marginTop: 16 }}>{status}</p>}

      {downloadUrl && (
        <p>
          <a href={downloadUrl} target="_blank" rel="noreferrer">Open uploaded file (pre-signed, expires in 2 min)</a>
        </p>
      )}
    </div>
  );
}

// PUT a file to a pre-signed URL with upload progress.
// IMPORTANT: Content-Type MUST match what the server signed, or S3 returns SignatureDoesNotMatch.
function putWithProgress(url, file, onProgress) {
  return new Promise((resolve, reject) => {
    const xhr = new XMLHttpRequest();
    xhr.open('PUT', url, true);
    xhr.setRequestHeader('Content-Type', file.type);
    xhr.upload.onprogress = (evt) => {
      if (evt.lengthComputable) onProgress(Math.round((evt.loaded / evt.total) * 100));
    };
    xhr.onload = () => (xhr.status >= 200 && xhr.status < 300
      ? resolve()
      : reject(new Error(`S3 upload failed (${xhr.status})`)));
    xhr.onerror = () => reject(new Error('Network/CORS error during upload'));
    xhr.send(file);
  });
}
