import { useState, useEffect } from 'react'

interface PDFDisplayProps {
  pdfUrl: string | undefined
  onLoadSuccess?: (numPages: number) => void
  onLoadError?: (error: Error) => void
}

export function PDFDisplay({ pdfUrl, onLoadError }: PDFDisplayProps) {
  const [blobUrl, setBlobUrl] = useState<string | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!pdfUrl) return

    let revoke: string | null = null
    setLoading(true)
    setError(null)

    fetch(pdfUrl)
      .then(res => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`)
        return res.blob()
      })
      .then(blob => {
        const url = URL.createObjectURL(
          new Blob([blob], { type: 'application/pdf' })
        )
        revoke = url
        setBlobUrl(url)
      })
      .catch(err => {
        setError('Failed to load PDF')
        onLoadError?.(err)
      })
      .finally(() => setLoading(false))

    return () => {
      if (revoke) URL.revokeObjectURL(revoke)
    }
  }, [pdfUrl, onLoadError])

  if (!pdfUrl || loading) {
    return (
      <div className="flex flex-col items-center justify-center h-full gap-3 text-slate-400">
        <div className="animate-spin h-8 w-8 border-2 border-slate-500 border-t-slate-300 rounded-full" />
        <p>Loading PDF…</p>
      </div>
    )
  }

  if (error) {
    return (
      <div className="flex items-center justify-center h-full">
        <p className="text-red-400">{error}</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full">
      <object
        data={blobUrl ?? undefined}
        type="application/pdf"
        className="flex-1 w-full h-full bg-slate-900"
        aria-label="PDF Viewer"
      >
        <div className="flex flex-col items-center justify-center h-full gap-3 text-slate-400">
          <p>Your browser cannot display this PDF inline.</p>
          {pdfUrl && (
            <a
              href={pdfUrl}
              target="_blank"
              rel="noreferrer"
              className="text-primary-400 underline"
            >
              Open in new tab
            </a>
          )}
        </div>
      </object>
    </div>
  )
}
