import { useActiveAccount, useReadContract } from "thirdweb/react"
import { prepareContractCall } from "thirdweb"
import { useSendTransaction } from "thirdweb/react"
import { useUsernameRegistryContract } from "./useContracts"
import { useState, useEffect } from "react"

/**
 * Hook to register a username
 * @param username The username to register
 */
export function useRegisterUsername(username: string) {
  const contract = useUsernameRegistryContract()
  const { mutate: sendTransaction, data: transactionResult, isPending, error } = useSendTransaction()

  const registerUsername = async () => {
    if (!username || username.length < 3 || username.length > 32) {
      throw new Error("Username must be between 3 and 32 characters")
    }

    const transaction = prepareContractCall({
      contract,
      method: "function registerUsername(string)",
      params: [username],
    })

    sendTransaction(transaction)
  }

  return {
    registerUsername,
    isPending,
    isConfirming: isPending,
    isSuccess: !!transactionResult && !error,
    hash: transactionResult?.transactionHash,
    error,
  }
}

/**
 * Hook to get user profile with username
 * @param address Address to query (defaults to connected wallet)
 */
export function useUserProfile(address?: string) {
  const contract = useUsernameRegistryContract()
  const account = useActiveAccount()
  const addressToQuery = address || account?.address

  const { data, isLoading, error, refetch } = useReadContract({
    contract,
    method: "getProfile",
    params: addressToQuery ? [addressToQuery] as any : undefined,
  })

  // Data is now a struct object, not an array
  const profile = data ? {
    username: (data as any).username || "",
    ensName: (data as any).ensName || "",
    ensNode: (data as any).ensNode || "",
    registeredAt: (data as any).registeredAt ? BigInt((data as any).registeredAt.toString()) : BigInt(0),
    isActive: Boolean((data as any).isActive),
    hasUsername: Boolean((data as any).isActive && (data as any).username && (data as any).username.length > 0),
  } : null

  return { profile, isLoading, error, refetch }
}

/**
 * Hook to check if a username is available
 * @param username Username to check
 */
export function useUsernameAvailability(username: string) {
  const contract = useUsernameRegistryContract()
  const [debouncedUsername, setDebouncedUsername] = useState(username)

  // Debounce username check by 500ms
  useEffect(() => {
    const timer = setTimeout(() => {
      setDebouncedUsername(username)
    }, 500)

    return () => clearTimeout(timer)
  }, [username])

  const { data: isAvailable, isLoading, error } = useReadContract({
    contract,
    method: "function isUsernameAvailable(string) view returns (bool)",
    params: debouncedUsername && debouncedUsername.length >= 3 ? [debouncedUsername] as any  : undefined,
  })

  return {
    isAvailable: Boolean(isAvailable),
    isLoading,
    error,
    isChecking: isLoading,
  }
}

/**
 * Hook to resolve an identifier (username or address) to an address
 * @param identifier Username or address to resolve
 */
export function useResolveIdentifier(identifier?: string) {
  const contract = useUsernameRegistryContract()

  const { data: resolvedAddress, isLoading, error } = useReadContract({
    contract,
    method: "function resolveIdentifier(string) view returns (address)",
    params: identifier ? [identifier] as any : undefined,
  })

  return {
    resolvedAddress: resolvedAddress as string | undefined,
    isLoading,
    error,
  }
}

/**
 * Hook to get address from username
 * @param username Username to look up
 */
export function useAddressFromUsername(username?: string) {
  const contract = useUsernameRegistryContract()

  const { data: address, isLoading, error } = useReadContract({
    contract,
    method: "function getUserAddress(string) view returns (address)",
    params: username ? [username] as any : undefined,
  })

  return {
    address: address as string | undefined,
    isLoading,
    error,
  }
}

/**
 * Hook to get username from address
 * @param address Address to look up
 */
export function useUsernameFromAddress(address?: string) {
  const contract = useUsernameRegistryContract()

  const { data: username, isLoading, error } = useReadContract({
    contract,
    method: "getUsername",
    params: address ? [address] as any : undefined,
  })

  return {
    username: username as string | undefined,
    isLoading,
    error,
  }
}

/**
 * Hook to get display name (username or shortened address)
 * @param address Address to look up
 * @returns Display name with @ prefix for usernames, shortened address otherwise
 */
export function useDisplayName(address?: string) {
  const contract = useUsernameRegistryContract()

  const { data, isLoading } = useReadContract({
    contract,
    method: "getProfile",
    params: address ? [address] as any : undefined,
  })

  // Check if user has an active profile with username
  const profile = data ? {
    username: (data as any).username || "",
    isActive: Boolean((data as any).isActive),
  } : null

  // Return formatted display name
  const displayName = profile?.isActive && profile.username
    ? `@${profile.username}`
    : address
      ? `${address.slice(0, 6)}...${address.slice(-4)}`
      : "Unknown"

  return {
    displayName,
    hasUsername: Boolean(profile?.isActive && profile.username),
    isLoading,
  }
}

/**
 * Hook to check if username is valid format
 * @param username Username to validate
 */
export function useValidateUsernameFormat(username: string) {
  const isValidLength = username.length >= 3 && username.length <= 32
  const isValidChars = /^[a-zA-Z0-9_]+$/.test(username)
  const isValid = isValidLength && isValidChars

  let errorMessage = ""
  if (!isValidLength) {
    errorMessage = "Username must be between 3 and 32 characters"
  } else if (!isValidChars) {
    errorMessage = "Username can only contain letters, numbers, and underscores"
  }

  return {
    isValid,
    errorMessage,
    isValidLength,
    isValidChars,
  }
}
