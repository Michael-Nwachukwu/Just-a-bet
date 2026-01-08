"use client"

import { useState } from "react"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Button } from "@/components/ui/button"
import { AlertCircle, CheckCircle2, Loader2 } from "lucide-react"
import {
  useRegisterUsername,
  useUsernameAvailability,
  useValidateUsernameFormat,
} from "@/lib/hooks/useUsernameRegistry"

export default function UsernameRegistration() {
  const [username, setUsername] = useState("")
  const { isValid, errorMessage } = useValidateUsernameFormat(username)
  const { isAvailable, isChecking } = useUsernameAvailability(username)
  const { registerUsername, isPending, isSuccess, hash, error } = useRegisterUsername(username)

  const canRegister = username.length >= 3 && isValid && isAvailable && !isPending && !isSuccess

  const handleRegister = async () => {
    if (!canRegister) return
    try {
      await registerUsername()
    } catch (err) {
      console.error("Failed to register username:", err)
    }
  }

  // Show success state
  if (isSuccess) {
    return (
      <Card className="border-green-500/50">
        <CardContent className="pt-6">
          <div className="flex items-center gap-3 text-green-500">
            <CheckCircle2 className="h-6 w-6" />
            <div>
              <p className="font-semibold">Username registered successfully!</p>
              <p className="text-sm text-muted-foreground">
                Your username <span className="text-primary">@{username}</span> is now active
              </p>
              {hash && (
                <p className="text-xs text-muted-foreground mt-1">
                  Transaction: {hash.slice(0, 10)}...{hash.slice(-8)}
                </p>
              )}
            </div>
          </div>
        </CardContent>
      </Card>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Register Username</CardTitle>
        <CardDescription>
          Choose a unique username for your betting profile (3-32 characters, alphanumeric and underscores only)
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="space-y-2">
          <div className="relative">
            <Input
              type="text"
              placeholder="Enter username"
              value={username}
              onChange={(e) => setUsername(e.target.value.toLowerCase())}
              disabled={isPending}
              className="pr-10"
            />
            {username.length >= 3 && (
              <div className="absolute right-3 top-1/2 -translate-y-1/2">
                {isChecking ? (
                  <Loader2 className="h-4 w-4 animate-spin text-muted-foreground" />
                ) : isValid && isAvailable ? (
                  <CheckCircle2 className="h-4 w-4 text-green-500" />
                ) : (
                  <AlertCircle className="h-4 w-4 text-red-500" />
                )}
              </div>
            )}
          </div>

          {/* Validation messages */}
          {username.length > 0 && (
            <div className="text-sm">
              {!isValid && errorMessage && (
                <p className="text-red-500 flex items-center gap-1">
                  <AlertCircle className="h-3 w-3" />
                  {errorMessage}
                </p>
              )}
              {isValid && username.length >= 3 && !isChecking && !isAvailable && (
                <p className="text-red-500 flex items-center gap-1">
                  <AlertCircle className="h-3 w-3" />
                  Username is already taken
                </p>
              )}
              {isValid && isAvailable && username.length >= 3 && (
                <p className="text-green-500 flex items-center gap-1">
                  <CheckCircle2 className="h-3 w-3" />
                  Username is available!
                </p>
              )}
            </div>
          )}
        </div>

        {/* Error display */}
        {error && (
          <div className="rounded-lg bg-red-500/10 border border-red-500/50 p-3">
            <p className="text-sm text-red-500 flex items-center gap-2">
              <AlertCircle className="h-4 w-4" />
              {error.message || "Failed to register username. Please try again."}
            </p>
          </div>
        )}

        <Button
          onClick={handleRegister}
          disabled={!canRegister}
          className="w-full"
        >
          {isPending ? (
            <>
              <Loader2 className="h-4 w-4 mr-2 animate-spin" />
              Registering...
            </>
          ) : (
            "Register Username"
          )}
        </Button>
      </CardContent>
    </Card>
  )
}
