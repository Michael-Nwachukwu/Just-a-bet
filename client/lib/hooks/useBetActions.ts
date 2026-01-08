import { useSendTransaction } from "thirdweb/react"
import { prepareContractCall, getContract } from "thirdweb"
import { client, mantleSepolia } from "@/lib/thirdweb"
import { ABIS } from "../contracts/abis"

/**
 * Get bet contract instance
 */
function getBetContract(betAddress: string) {
  return getContract({
    client,
    chain: mantleSepolia,
    address: betAddress as `0x${string}`,
    abi: ABIS.Bet,
  })
}

/**
 * Hook to accept a pending bet (become the opponent)
 */
export function useAcceptBet(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const acceptBet = () => {
    const transaction = prepareContractCall({
      contract,
      method: "function acceptBet()",
      params: [],
    })
    sendTransaction(transaction)
  }

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
 * Hook to fund stake (creator or opponent)
 */
export function useFundBet(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const fundStake = () => {
    const transaction = prepareContractCall({
      contract,
      method: "function fundStake()",
      params: [],
    })
    sendTransaction(transaction)
  }

  return {
    fundStake,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to declare outcome (winner declares first)
 */
export function useDeclareOutcome(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const declareOutcome = (outcome: number) => {
    // 1 = CreatorWins, 2 = OpponentWins, 3 = Draw
    const transaction = prepareContractCall({
      contract,
      method: "function declareOutcome(uint8)",
      params: [outcome],
    })
    sendTransaction(transaction)
  }

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
 * Hook to agree with declared outcome
 */
export function useAgreeWithOutcome(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const agreeWithOutcome = () => {
    const transaction = prepareContractCall({
      contract,
      method: "function agreeWithOutcome()",
      params: [],
    })
    sendTransaction(transaction)
  }

  return {
    agreeWithOutcome,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to raise a dispute
 */
export function useRaiseDispute(betAddress: string) {
  const contract = getBetContract(betAddress)
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const raiseDispute = (reason: string) => {
    const transaction = prepareContractCall({
      contract,
      method: "function raiseDispute(string)",
      params: [reason],
    })
    sendTransaction(transaction)
  }

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

  const claimWinnings = () => {
    const transaction = prepareContractCall({
      contract,
      method: "function claimWinnings()",
      params: [],
    })
    sendTransaction(transaction)
  }

  return {
    claimWinnings,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}
