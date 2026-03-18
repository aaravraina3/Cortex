import { useEffect } from 'react'
import { useGetSignedUrl } from '../../hooks/files.hooks'
import { useRetryExtract } from '../../hooks/preprocess.hooks'
import { PDFDisplay } from './PDFDisplay'
import { ExtractedDataPanel } from './ExtractedDataPanel'
import { Button } from '../ui/Button'
import type { FileUpload } from '../../types/file.types'

interface AdminDocumentViewerProps {
  file: FileUpload
  onClose: () => void
}

export function AdminDocumentViewer({
  file,
  onClose,
}: AdminDocumentViewerProps) {
  const { signedUrl, signedUrlIsLoading } = useGetSignedUrl(file)
  const { retryExtract, isRetryingExtract } = useRetryExtract()

  useEffect(() => {
    const modalElement = document.querySelector(
      '.admin-modal-container'
    ) as HTMLElement
    modalElement?.focus()
  }, [])

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        onClose()
      }
    }

    window.addEventListener('keydown', handleKeyDown, { capture: true })
    return () =>
      window.removeEventListener('keydown', handleKeyDown, { capture: true })
  }, [onClose])

  const handleRetryExtract = async () => {
    try {
      await retryExtract(file.id)
    } catch (error) {
      console.error('Retry extraction failed:', error)
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="absolute inset-0 bg-slate-900/80" onClick={onClose} />

      <div
        className="relative bg-slate-800 border border-slate-700 rounded-xl shadow-2xl w-[95vw] h-[95vh] flex flex-col admin-modal-container"
        tabIndex={-1}
      >
        {/* Header */}
        <div className="flex items-center justify-between p-4 border-b border-slate-700">
          <h2 className="text-lg font-semibold text-slate-100 truncate">
            {file.name}
          </h2>

          <div className="flex items-center space-x-2">
            <Button
              onClick={() => signedUrl && window.open(signedUrl, '_blank')}
              variant="secondary"
              size="sm"
              disabled={!signedUrl}
            >
              Open in new tab
            </Button>
            <Button
              onClick={handleRetryExtract}
              variant="secondary"
              size="sm"
              loading={isRetryingExtract}
            >
              Retry Extraction
            </Button>
            <button
              onClick={onClose}
              className="text-slate-400 hover:text-slate-200 transition-colors"
            >
              <svg
                className="w-6 h-6"
                fill="none"
                stroke="currentColor"
                viewBox="0 0 24 24"
              >
                <path
                  strokeLinecap="round"
                  strokeLinejoin="round"
                  strokeWidth={2}
                  d="M6 18L18 6M6 6l12 12"
                />
              </svg>
            </button>
          </div>
        </div>

        {/* Split View */}
        <div className="flex-1 flex overflow-hidden">
          {/* Left: PDF */}
          <div className="w-1/2 border-r border-slate-700">
            {signedUrlIsLoading ? (
              <div className="flex flex-col items-center justify-center h-full gap-3 text-slate-400">
                <div className="animate-spin h-8 w-8 border-2 border-slate-500 border-t-slate-300 rounded-full" />
                <p>Loading PDF… Large files may take a moment</p>
              </div>
            ) : signedUrl ? (
              <PDFDisplay pdfUrl={signedUrl} />
            ) : (
              <div className="flex items-center justify-center h-full">
                <div className="text-red-400">Failed to load PDF</div>
              </div>
            )}
          </div>

          {/* Right: Extracted Data */}
          <div className="w-1/2">
            <ExtractedDataPanel sourceFileId={file.id} />
          </div>
        </div>
      </div>
    </div>
  )
}
