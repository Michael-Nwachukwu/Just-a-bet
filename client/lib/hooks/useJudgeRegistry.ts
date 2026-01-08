import { useActiveAccount, useReadContract } from "thirdweb/react"
import { prepareContractCall, toEther, toWei } from "thirdweb"
import { useSendTransaction } from "thirdweb/react"
import { useJudgeRegistryContract } from "./useContracts"

/**
 * Hook to register as a judge with MNT stake
 * @param stakeAmount Amount of MNT to stake (in ether, e.g., "1.5")
 */
export function useJudgeRegistration(stakeAmount: string) {
  const contract = useJudgeRegistryContract()
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const registerJudge = async () => {
    if (!stakeAmount || parseFloat(stakeAmount) <= 0) {
      throw new Error("Invalid stake amount")
    }

    const transaction = prepareContractCall({
      contract,
      method: "function registerJudge() payable",
      params: [],
      value: toWei(stakeAmount),
      gas: BigInt(500000), // Explicit gas limit to prevent "gas limit too low" errors
    })

    sendTransaction(transaction)
  }

  return {
    registerJudge,
    isPending,
    transactionResult,
    error,
  }
}

/**
 * Hook to increase judge stake
 * @param additionalStake Amount of additional MNT to stake (in ether)
 */
export function useIncreaseStake(additionalStake: string) {
  const contract = useJudgeRegistryContract()
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const increaseStake = async () => {
    if (!additionalStake || parseFloat(additionalStake) <= 0) {
      throw new Error("Invalid stake amount")
    }

    const transaction = prepareContractCall({
      contract,
      method: "function increaseStake() payable",
      params: [],
      value: toWei(additionalStake),
    })

    sendTransaction(transaction)
  }

  return {
    increaseStake,
    isPending,
    transactionResult,
    error,
  }
}

/**
 * Hook to request withdrawal (starts lock period)
 */
export function useRequestWithdrawal() {
  const contract = useJudgeRegistryContract()
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const requestWithdrawal = () => {
    const transaction = prepareContractCall({
      contract,
      method: "function requestWithdrawal()",
      params: [],
    })

    sendTransaction(transaction)
  }

  return {
    requestWithdrawal,
    isPending,
    transactionResult,
    error,
  }
}

/**
 * Hook to complete withdrawal after lock period
 */
export function useCompleteWithdrawal() {
  const contract = useJudgeRegistryContract()
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const completeWithdrawal = () => {
    const transaction = prepareContractCall({
      contract,
      method: "function completeWithdrawal()",
      params: [],
    })

    sendTransaction(transaction)
  }

  return {
    completeWithdrawal,
    isPending,
    transactionResult,
    error,
  }
}

/**
 * Hook to get judge profile for a specific address
 * @param judgeAddress Address of the judge to query
 */
export function useJudgeProfile(judgeAddress?: string) {
  const contract = useJudgeRegistryContract()
  const account = useActiveAccount()
  const addressToQuery = judgeAddress || account?.address

  const { data, isLoading, error, refetch } = useReadContract({
    contract,
    method: "function getJudgeProfile(address) view returns (uint256, uint256, uint256, uint256, uint256, bool, uint256)",
    params: addressToQuery ? [addressToQuery] as any : undefined,
  })

  const { data: isEligible, isLoading: isEligibleLoading } = useReadContract({
    contract,
    method: "function isEligible(address) view returns (bool)",
    params: addressToQuery ? [addressToQuery] as any : undefined,
  })

  // Parse the profile data
  const profile = data && Array.isArray(data) && data.length >= 7 ? {
    judgeAddress: addressToQuery as string,
    stakedAmount: data[0] != null ? BigInt(data[0].toString()) : BigInt(0),
    reputationScore: data[1] != null ? BigInt(data[1].toString()) : BigInt(0),
    casesJudged: data[2] != null ? BigInt(data[2].toString()) : BigInt(0),
    successfulCases: data[3] != null ? BigInt(data[3].toString()) : BigInt(0),
    registrationTime: data[4] != null ? BigInt(data[4].toString()) : BigInt(0),
    isActive: data[5] != null ? Boolean(data[5]) : false,
    withdrawRequestTime: data[6] != null ? BigInt(data[6].toString()) : BigInt(0),
    isEligible: isEligible != null ? Boolean(isEligible) : false,
    // Calculated fields with null checks
    stakedAmountFormatted: data[0] != null && data[0] !== undefined
      ? toEther(BigInt(data[0].toString()))
      : "0",
    successRate: data[2] != null && BigInt(data[2].toString()) > BigInt(0)
      ? Number(BigInt(data[3]?.toString() ?? "0") * BigInt(10000) / BigInt(data[2].toString())) / 100
      : 0,
    reputationPercentage: data[1] != null && data[1] !== undefined
      ? Number(data[1]) / 100
      : 0, // Reputation is 0-10000 (basis points)
  } : null

  return {
    profile,
    isLoading: isLoading || isEligibleLoading,
    error,
    refetch,
  }
}

/**
 * Hook to check withdrawal availability for a judge
 * @param judgeAddress Address of the judge to query
 */
export function useWithdrawalStatus(judgeAddress?: string) {
  const contract = useJudgeRegistryContract()
  const account = useActiveAccount()
  const addressToQuery = judgeAddress || account?.address

  const { data, isLoading, error, refetch } = useReadContract({
    contract,
    method: "function getWithdrawalAvailability(address) view returns (bool, uint256, uint256)",
    params: addressToQuery ? [addressToQuery] as any : undefined,
  })

  const withdrawalStatus = data ? {
    canWithdraw: Boolean(data[0]),
    withdrawalRequestTime: BigInt(data[1]?.toString() ?? "0"),
    withdrawalAvailableTime: BigInt(data[2]?.toString() ?? "0"),
    timeRemaining: BigInt(data[2]?.toString() ?? "0") > BigInt(Math.floor(Date.now() / 1000))
      ? BigInt(data[2]?.toString() ?? "0") - BigInt(Math.floor(Date.now() / 1000))
      : BigInt(0),
  } : null

  return {
    withdrawalStatus,
    isLoading,
    error,
    refetch,
  }
}

/**
 * Hook to check if an address is an eligible judge
 * @param judgeAddress Address to check
 */
export function useIsEligibleJudge(judgeAddress?: string) {
  const contract = useJudgeRegistryContract()
  const account = useActiveAccount()
  const addressToQuery = judgeAddress || account?.address

  const { data: isEligible, isLoading, error } = useReadContract({
    contract,
    method: "function isEligible(address) view returns (bool)",
    params: addressToQuery ? [addressToQuery] as any : undefined,
  })

  return {
    isEligible: Boolean(isEligible),
    isLoading,
    error,
  }
}

/**
 * Hook to get judge registry configuration
 */
export function useJudgeRegistryConfig() {
  const contract = useJudgeRegistryContract()

  const { data, isLoading, error } = useReadContract({
    contract,
    method: "function config() view returns (uint256, uint256, uint256, uint256)",
  })

  const config = data ? {
    minStakeAmount: BigInt(data[0]?.toString() ?? "0"),
    minReputationScore: BigInt(data[1]?.toString() ?? "0"),
    withdrawalLockPeriod: BigInt(data[2]?.toString() ?? "0"),
    slashPercentage: BigInt(data[3]?.toString() ?? "0"),
    // Formatted versions
    minStakeFormatted: toEther(BigInt(data[0]?.toString() ?? "0")),
    withdrawalLockDays: Number(data[2]?.toString() ?? "0") / 86400,
    slashPercentageFormatted: Number(data[3]?.toString() ?? "0") / 100,
  } : null

  return {
    config,
    isLoading,
    error,
  }
}

/**
 * Hook to get total number of active judges
 */
export function useActiveJudgesCount() {
  const contract = useJudgeRegistryContract()

  const { data: count, isLoading, error } = useReadContract({
    contract,
    method: "function getActiveJudgesCount() view returns (uint256)",
  })

  return {
    count: count ? BigInt(count.toString()) : BigInt(0),
    isLoading,
    error,
  }
}

/**
 * Hook to get an active judge address by index
 * @param index Index in the activeJudges array
 */
export function useActiveJudgeByIndex(index: number) {
  const contract = useJudgeRegistryContract()

  const { data: judgeAddress, isLoading, error } = useReadContract({
    contract,
    method: "function activeJudges(uint256) view returns (address)",
    params: [BigInt(index)],
  })

  return {
    judgeAddress: judgeAddress as string,
    isLoading,
    error,
  }
}

/**
 * Hook to fetch all active judges
 * Note: This makes multiple calls, use sparingly
 */
export function useAllActiveJudges() {
  const { count, isLoading: isCountLoading } = useActiveJudgesCount()
  const judgeCount = count ? Number(count) : 0

  // We'll need to fetch judges individually
  // This is a simplified version - in production, consider batching or backend indexing
  return {
    judgeCount,
    isLoading: isCountLoading,
  }
}
