import { useEffect } from 'react'
import { useGetSignedUrl } from '../../hooks/files.hooks'
import { PDFDisplay } from '../documents/PDFDisplay'
import { Button } from './Button'
import type { FileUpload } from '../../types/file.types'

interface ViewPDFModalProps {
  file: FileUpload
  onClose: () => void
}

export function ViewPDFModal({ file, onClose }: ViewPDFModalProps) {
  const { signedUrl, signedUrlIsLoading } = useGetSignedUrl(file)

  useEffect(() => {
    const modalElement = document.querySelector(
      '.pdf-modal-container'
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

  const downloadPDF = async () => {
    if (signedUrl) {
      try {
        const response = await fetch(signedUrl)
        const blob = await response.blob()
        const url = window.URL.createObjectURL(blob)
        const link = document.createElement('a')
        link.href = url
        link.download = file.name
        link.style.display = 'none'
        document.body.appendChild(link)
        link.click()
        document.body.removeChild(link)
        window.URL.revokeObjectURL(url)
      } catch (error) {
        console.error('Download failed:', error)
        window.open(signedUrl, '_blank')
      }
    }
  }

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="absolute inset-0 bg-slate-900/80" onClick={onClose} />

      <div
        className="relative bg-slate-800 border border-slate-700 rounded-xl shadow-2xl w-[90vw] h-[90vh] flex flex-col pdf-modal-container"
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
              onClick={downloadPDF}
              variant="secondary"
              size="sm"
              disabled={!signedUrl}
            >
              Download
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

        {/* Content */}
        <div className="flex-1 overflow-hidden">
          {signedUrlIsLoading ? (
            <div className="flex flex-col items-center justify-center h-full gap-3 text-slate-400">
              <div className="animate-spin h-8 w-8 border-2 border-slate-500 border-t-slate-300 rounded-full" />
              <p>Loading document…</p>
            </div>
          ) : signedUrl ? (
            file.type === 'pdf' ? (
              <PDFDisplay pdfUrl={signedUrl} />
            ) : (
              <div className="flex flex-col items-center justify-center h-full gap-4 text-slate-400">
                <svg className="w-16 h-16" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={1.5} d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
                </svg>
                <p className="text-lg">CSV files cannot be previewed</p>
                <Button onClick={downloadPDF} variant="primary" size="sm">
                  Download {file.name}
                </Button>
              </div>
            )
          ) : (
            <div className="flex items-center justify-center h-full">
              <div className="text-red-400">Failed to load document</div>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
