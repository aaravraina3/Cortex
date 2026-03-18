import { useQuery } from '@tanstack/react-query'
import api from '../config/axios.config'
import { QUERY_KEYS } from '../utils/constants'

export function useGetTenantSample(tenantId: string | undefined) {
  const query = useQuery({
    queryKey: QUERY_KEYS.samples.forTenant(tenantId),
    queryFn: async () => {
      if (!tenantId) return null
      const { data } = await api.get<{ name: string; description: string; files: string[]; count: number } | null>(
        `/samples/for-tenant-id/${tenantId}`
      )
      return data
    },
    enabled: !!tenantId,
  })

  return {
    tenantSample: query.data,
    tenantSampleIsLoading: query.isLoading,
    tenantSampleError: query.error,
  }
}
