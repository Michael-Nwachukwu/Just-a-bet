import { useWriteContract, useWaitForTransactionReceipt, useReadContract } from "wagmi"
import { parseUnits, Address } from "viem"
import { useBetFactoryContract, useUSDCContract } from "./useContracts"

/**
 * Hook for creating a new bet
 */
export function useCreateBet() {
  const betFactory = useBetFactoryContract()
  const { writeContract, data: hash, isPending, error } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const createBet = async (params: {
    opponentIdentifier: string
    stakeAmount: string // in USDC
    description: string
    outcomeDescription: string
    duration: number // in seconds
    tags: string[]
  }) => {
    // Convert stake amount to 6 decimals (USDC)
    const stakeAmountWei = parseUnits(params.stakeAmount, 6)

    writeContract({
      address: betFactory.address,
      abi: betFactory.abi,
      functionName: "createBet",
      args: [
        params.opponentIdentifier,
        stakeAmountWei,
        params.description,
        params.outcomeDescription,
        BigInt(params.duration),
        params.tags,
      ],
    })
  }

  return {
    createBet,
    hash,
    isPending,
    isConfirming,
    isSuccess,
    error,
  }
}

/**
 * Hook for checking and approving USDC spending
 */
export function useUSDCApproval(spenderAddress: Address) {
  const usdc = useUSDCContract()
  const { writeContract, data: hash, isPending } = useWriteContract()

  const { isLoading: isConfirming, isSuccess } = useWaitForTransactionReceipt({
    hash,
  })

  const approve = async (amount: string) => {
    const amountWei = parseUnits(amount, 6)

    writeContract({
      address: usdc.address,
      abi: usdc.abi,
      functionName: "approve",
      args: [spenderAddress, amountWei],
    })
  }

  return {
    approve,
    hash,
    isPending,
    isConfirming,
    isSuccess,
  }
}

/**
 * Hook to check USDC allowance
 */
export function useUSDCAllowance(owner: Address | undefined, spender: Address) {
  const usdc = useUSDCContract()

  const { data: allowance, refetch } = useReadContract({
    address: usdc.address,
    abi: usdc.abi,
    functionName: "allowance",
    args: owner ? [owner, spender] : undefined,
    query: {
      enabled: !!owner,
    },
  })

  return {
    allowance: allowance as bigint | undefined,
    refetch,
  }
}

/**
 * Hook to check USDC balance
 */
export function useUSDCBalance(address: Address | undefined) {
  const usdc = useUSDCContract()

  const { data: balance, refetch } = useReadContract({
    address: usdc.address,
    abi: usdc.abi,
    functionName: "balanceOf",
    args: address ? [address] : undefined,
    query: {
      enabled: !!address,
    },
  })

  return {
    balance: balance as bigint | undefined,
    refetch,
  }
}
