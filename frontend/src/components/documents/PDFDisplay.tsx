interface PDFDisplayProps {
  pdfUrl: string | undefined
  onLoadSuccess?: (numPages: number) => void
  onLoadError?: (error: Error) => void
}

export function PDFDisplay({ pdfUrl, onLoadError }: PDFDisplayProps) {
  if (!pdfUrl) {
    return (
      <div className="flex flex-col items-center justify-center h-full gap-3 text-slate-400">
        <div className="animate-spin h-8 w-8 border-2 border-slate-500 border-t-slate-300 rounded-full" />
        <p>Loading PDF…</p>
      </div>
    )
  }

  return (
    <div className="flex flex-col h-full">
      <iframe
        src={pdfUrl}
        className="flex-1 w-full h-full border-0 bg-slate-900"
        title="PDF Viewer"
        onError={() => onLoadError?.(new Error('Failed to load PDF'))}
      />
    </div>
  )
}
