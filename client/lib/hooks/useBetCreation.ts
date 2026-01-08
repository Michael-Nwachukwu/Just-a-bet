import { useReadContract, useSendTransaction } from "thirdweb/react"
import { prepareContractCall, toUnits } from "thirdweb"
import { useBetFactoryContract, useUSDCContract } from "./useContracts"

/**
 * Hook for creating a new bet
 */
export function useCreateBet() {
  const betFactory = useBetFactoryContract()
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const createBet = (params: {
    opponentIdentifier: string
    stakeAmount: string // in USDC
    description: string
    outcomeDescription: string
    duration: number // in seconds
    tags: string[]
  }) => {
    console.log("createBet called with params:", params)

    try {
      // Convert stake amount to 6 decimals (USDC)
      const stakeAmountWei = toUnits(params.stakeAmount, 6)
      console.log("Stake amount in wei:", stakeAmountWei.toString())

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

      console.log("Transaction prepared:", transaction)
      console.log("Calling sendTransaction...")

      sendTransaction(transaction, {
        onSuccess: (result) => {
          console.log("Transaction successful:", result)
        },
        onError: (error) => {
          console.error("Transaction error:", error)
        },
      })
    } catch (err) {
      console.error("Error in createBet:", err)
      throw err
    }
  }

  return {
    createBet,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook for checking and approving USDC spending
 */
export function useUSDCApproval(spenderAddress: string) {
  const usdc = useUSDCContract()
  const { mutate: sendTransaction, data: transactionResult, isPending } = useSendTransaction()

  const approve = (amount: string) => {
    console.log("approve called with amount:", amount, "spender:", spenderAddress)

    try {
      const amountWei = toUnits(amount, 6)
      console.log("Approval amount in wei:", amountWei.toString())

      const transaction = prepareContractCall({
        contract: usdc,
        method: "function approve(address, uint256) returns (bool)",
        params: [spenderAddress, amountWei],
      })

      console.log("Approval transaction prepared:", transaction)

      sendTransaction(transaction, {
        onSuccess: (result) => {
          console.log("Approval successful:", result)
        },
        onError: (error) => {
          console.error("Approval error:", error)
        },
      })
    } catch (err) {
      console.error("Error in approve:", err)
      throw err
    }
  }

  return {
    approve,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult,
    hash: transactionResult?.transactionHash,
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
    params: owner ? [owner, spender] as any : undefined,
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
    params: address ? [address] as any : undefined,
  })

  return {
    balance: balance ? BigInt(balance.toString()) : undefined,
    refetch,
  }
}
