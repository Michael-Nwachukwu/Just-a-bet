import { useSendTransaction } from "thirdweb/react"
import { prepareContractCall, getContract } from "thirdweb"
import { client, mantleSepolia } from "@/lib/thirdweb"
import { ABIS } from "../contracts/abis"
import { useCallback } from "react"

/**
 * Get bet contract instance
 */
function getBetContract(betAddress: string) {
  return getContract({
    client,
    chain: mantleSepolia,
    address: betAddress as `0x${string}`,
    abi: ABIS.Bet as any,
  })
}

/**
 * Hook to accept a pending bet (become the opponent)
 */
export function useAcceptBet(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const acceptBet = useCallback((options?: { onSuccess?: (result: any) => void; onError?: (error: any) => void }) => {
    const transaction = prepareContractCall({
      contract,
      method: "function acceptBet()",
      params: [],
    })
    sendTransaction(transaction, {
      onSuccess: (result) => {
        if (options?.onSuccess) options.onSuccess(result)
      },
      onError: (error) => {
        if (options?.onError) options.onError(error)
      },
    })
  }, [contract, sendTransaction])

  return {
    acceptBet,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to fund creator stake
 */
export function useFundCreatorStake(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const fundCreator = useCallback((options?: { onSuccess?: (result: any) => void; onError?: (error: any) => void }) => {
    console.log("fundCreator called for bet:", betAddress)

    const transaction = prepareContractCall({
      contract,
      method: "function fundCreator()",
      params: [],
    })

    console.log("Transaction prepared:", transaction)

    sendTransaction(transaction, {
      onSuccess: (result) => {
        console.log("Fund creator successful:", result)
        if (options?.onSuccess) options.onSuccess(result)
      },
      onError: (error) => {
        console.error("Fund creator error:", error)
        if (options?.onError) options.onError(error)
      },
    })
  }, [contract, sendTransaction, betAddress])

  return {
    fundCreator,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Legacy hook name for backwards compatibility
 * @deprecated Use useFundCreatorStake instead
 */
export function useFundBet(betAddress: string) {
  return useFundCreatorStake(betAddress)
}

/**
 * Hook to declare outcome (winner declares first)
 */
export function useDeclareOutcome(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const declareOutcome = useCallback((outcome: number, options?: { onSuccess?: (result: any) => void; onError?: (error: any) => void }) => {
    // 1 = CreatorWins, 2 = OpponentWins, 3 = Draw
    const transaction = prepareContractCall({
      contract,
      method: "function declareOutcome(uint8)",
      params: [outcome],
    })
    sendTransaction(transaction, {
      onSuccess: (result) => {
        if (options?.onSuccess) options.onSuccess(result)
      },
      onError: (error) => {
        if (options?.onError) options.onError(error)
      },
    })
  }, [contract, sendTransaction])

  return {
    declareOutcome,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to finalize resolution after dispute window expires
 * (This is how the other party "agrees" - by not disputing and waiting for window to expire)
 */
export function useFinalizeResolution(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const finalizeResolution = useCallback((options?: { onSuccess?: (result: any) => void; onError?: (error: any) => void }) => {
    const transaction = prepareContractCall({
      contract,
      method: "function finalizeResolution()",
      params: [],
    })
    sendTransaction(transaction, {
      onSuccess: (result) => {
        if (options?.onSuccess) options.onSuccess(result)
      },
      onError: (error) => {
        if (options?.onError) options.onError(error)
      },
    })
  }, [contract, sendTransaction])

  return {
    finalizeResolution,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to raise a dispute
 * Note: The reason is not stored on-chain in the Bet contract, but should be submitted to DisputeManager
 */
export function useRaiseDispute(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const raiseDispute = useCallback((options?: { onSuccess?: (result: any) => void; onError?: (error: any) => void }) => {
    const transaction = prepareContractCall({
      contract,
      method: "function raiseDispute()",
      params: [],
    })
    sendTransaction(transaction, {
      onSuccess: (result) => {
        if (options?.onSuccess) options.onSuccess(result)
      },
      onError: (error) => {
        if (options?.onError) options.onError(error)
      },
    })
  }, [contract, sendTransaction])

  return {
    raiseDispute,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to cancel a bet (only if not funded yet)
 */
export function useCancelBet(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const cancelBet = () => {
    const transaction = prepareContractCall({
      contract,
      method: "function cancelBet()",
      params: [],
    })
    sendTransaction(transaction)
  }

  return {
    cancelBet,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to claim winnings after bet is resolved
 */
export function useClaimWinnings(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const claimWinnings = useCallback((options?: { onSuccess?: (result: any) => void; onError?: (error: any) => void }) => {
    const transaction = prepareContractCall({
      contract,
      method: "function claimWinnings()",
      params: [],
    })
    sendTransaction(transaction, {
      onSuccess: (result) => {
        if (options?.onSuccess) options.onSuccess(result)
      },
      onError: (error) => {
        if (options?.onError) options.onError(error)
      },
    })
  }, [contract, sendTransaction])

  return {
    claimWinnings,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}
