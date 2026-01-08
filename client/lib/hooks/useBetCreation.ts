import { useReadContract, useSendTransaction } from "thirdweb/react"
import { prepareContractCall, toUnits } from "thirdweb"
import { useBetFactoryContract, useUSDCContract } from "./useContracts"

/**
 * Hook for creating a new bet
 */
export function useCreateBet() {
  const betFactory = useBetFactoryContract()
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const createBet = async (params: {
    opponentIdentifier: string
    stakeAmount: string // in USDC
    description: string
    outcomeDescription: string
    duration: number // in seconds
    tags: string[]
  }) => {
    // Convert stake amount to 6 decimals (USDC)
    const stakeAmountWei = toUnits(params.stakeAmount, 6)

    const transaction = prepareContractCall({
      contract: betFactory,
      method: "function createBet(string, uint256, string, string, uint256, string[])",
      params: [
        params.opponentIdentifier,
        stakeAmountWei,
        params.description,
        params.outcomeDescription,
        BigInt(params.duration),
        params.tags,
      ],
    })

    sendTransaction(transaction)
  }

  return {
    createBet,
    transactionResult,
    isPending,
    error,
  }
}

/**
 * Hook for checking and approving USDC spending
 */
export function useUSDCApproval(spenderAddress: string) {
  const usdc = useUSDCContract()
  const { mutate: sendTransaction, data: transactionResult, isPending } = useSendTransaction()

  const approve = async (amount: string) => {
    const amountWei = toUnits(amount, 6)

    const transaction = prepareContractCall({
      contract: usdc,
      method: "function approve(address, uint256) returns (bool)",
      params: [spenderAddress, amountWei],
    })

    sendTransaction(transaction)
  }

  return {
    approve,
    transactionResult,
    isPending,
  }
}

/**
 * Hook to check USDC allowance
 */
export function useUSDCAllowance(owner: string | undefined, spender: string) {
  const usdc = useUSDCContract()

  const { data: allowance, refetch } = useReadContract({
    contract: usdc,
    method: "function allowance(address, address) view returns (uint256)",
    params: owner ? [owner, spender] : undefined,
  })

  return {
    allowance: allowance ? BigInt(allowance.toString()) : undefined,
    refetch,
  }
}

/**
 * Hook to check USDC balance
 */
export function useUSDCBalance(address: string | undefined) {
  const usdc = useUSDCContract()

  const { data: balance, refetch } = useReadContract({
    contract: usdc,
    method: "function balanceOf(address) view returns (uint256)",
    params: address ? [address] : undefined,
  })

  return {
    balance: balance ? BigInt(balance.toString()) : undefined,
    refetch,
  }
}
