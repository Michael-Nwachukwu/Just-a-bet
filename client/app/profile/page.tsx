"use client"

import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Badge } from "@/components/ui/badge"

export default function ProfilePage() {
  return (
    <main className="pt-16 pb-20">
      <div className="max-w-4xl mx-auto px-6 py-12">
        <h1 className="text-4xl font-bold mb-8 uppercase">
          <span className="text-orange-500">USER</span> PROFILE
        </h1>

        <Tabs defaultValue="profile" className="w-full">
          <TabsList className="w-full justify-start bg-transparent border-b border-neutral-700 h-auto p-0 rounded-none">
            {[
              { value: "profile", label: "Profile" },
              { value: "positions", label: "Positions" },
              { value: "settings", label: "Settings" },
            ].map((tab) => (
              <TabsTrigger
                key={tab.value}
                value={tab.value}
                className="data-[state=active]:border-b-2 data-[state=active]:border-orange-500 rounded-none border-0 bg-transparent"
              >
                {tab.label}
              </TabsTrigger>
            ))}
          </TabsList>

          {/* Profile Tab */}
          <TabsContent value="profile" className="mt-8 space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Profile Information</CardTitle>
              </CardHeader>
              <CardContent className="space-y-6">
                <div className="flex gap-6 items-start">
                  <div className="w-24 h-24 bg-gradient-to-br from-orange-500 to-cyan-400 rounded-full flex items-center justify-center text-3xl font-bold">
                    U
                  </div>
                  <div className="flex-1">
                    <div className="mb-4">
                      <label className="block text-sm font-medium mb-2">Username</label>
                      <div className="text-lg font-bold">@username</div>
                    </div>
                    <div className="mb-4">
                      <label className="block text-sm font-medium mb-2">Wallet Address</label>
                      <div className="flex items-center gap-2">
                        <code className="text-sm bg-neutral-900 px-3 py-2 rounded">0x1234...5678</code>
                        <Button size="sm" variant="outline" className="bg-transparent">
                          Copy
                        </Button>
                      </div>
                    </div>
                    <div>
                      <label className="block text-sm font-medium mb-2">Member Since</label>
                      <div className="text-neutral-400">January 1, 2024</div>
                    </div>
                  </div>
                </div>
              </CardContent>
            </Card>

            {/* Stats */}
            <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
              {[
                { label: "Total Bets Created", value: "23" },
                { label: "Win Rate", value: "58%" },
                { label: "Total Volume", value: "$5,432" },
                { label: "Total Earned", value: "$234" },
              ].map((stat) => (
                <Card key={stat.label}>
                  <CardContent className="pt-6">
                    <div className="text-2xl font-bold text-orange-500 mb-1">{stat.value}</div>
                    <div className="text-xs text-neutral-400">{stat.label}</div>
                  </CardContent>
                </Card>
              ))}
            </div>
          </TabsContent>

          {/* Positions Tab */}
          <TabsContent value="positions" className="mt-8">
            <Card>
              <CardHeader>
                <CardTitle>Pool Positions</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="overflow-x-auto">
                  <table className="w-full text-sm">
                    <thead className="border-b border-neutral-700">
                      <tr>
                        <th className="text-left py-3 px-4 font-bold">Pool Name</th>
                        <th className="text-right py-3 px-4 font-bold">Deposited</th>
                        <th className="text-right py-3 px-4 font-bold">Current Value</th>
                        <th className="text-right py-3 px-4 font-bold">Earned</th>
                        <th className="text-center py-3 px-4 font-bold">Status</th>
                        <th className="text-center py-3 px-4 font-bold">Action</th>
                      </tr>
                    </thead>
                    <tbody>
                      {[
                        {
                          pool: "Sports Pool - NBA",
                          deposited: 500,
                          value: 525,
                          earned: 25,
                          status: "Unlocked",
                        },
                        {
                          pool: "Crypto Pool - BTC/ETH",
                          deposited: 1000,
                          value: 1050,
                          earned: 50,
                          status: "Locked (30d)",
                        },
                        {
                          pool: "Entertainment Pool",
                          deposited: 300,
                          value: 312,
                          earned: 12,
                          status: "Unlocked",
                        },
                      ].map((position) => (
                        <tr key={position.pool} className="border-b border-neutral-700 last:border-0">
                          <td className="py-4 px-4">{position.pool}</td>
                          <td className="text-right py-4 px-4">${position.deposited}</td>
                          <td className="text-right py-4 px-4">${position.value}</td>
                          <td className="text-right py-4 px-4 text-green-400">+${position.earned}</td>
                          <td className="text-center py-4 px-4 text-xs">
                            <Badge className="bg-orange-500/20 text-orange-400 border-0">{position.status}</Badge>
                          </td>
                          <td className="text-center py-4 px-4">
                            <Button size="sm" variant="outline" className="bg-transparent">
                              Withdraw
                            </Button>
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>
              </CardContent>
            </Card>
          </TabsContent>

          {/* Settings Tab */}
          <TabsContent value="settings" className="mt-8 space-y-6">
            <Card>
              <CardHeader>
                <CardTitle>Username</CardTitle>
              </CardHeader>
              <CardContent>
                <div className="space-y-4">
                  <div>
                    <label className="block text-sm font-medium mb-2">Current Username</label>
                    <div className="text-lg font-bold">@username</div>
                  </div>
                  <Button variant="outline" className="bg-transparent">
                    Change Username
                  </Button>
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Notifications</CardTitle>
              </CardHeader>
              <CardContent className="space-y-4">
                <div>
                  <label className="block text-sm font-medium mb-2">Email</label>
                  <Input type="email" placeholder="user@example.com" className="bg-neutral-800 border-neutral-700" />
                </div>
                <div className="space-y-3">
                  {[
                    { label: "Bet matched notifications", checked: true },
                    { label: "Verdict needed", checked: true },
                    { label: "Bet completed", checked: true },
                    { label: "Pool earnings", checked: false },
                  ].map((option) => (
                    <div key={option.label} className="flex items-center gap-3">
                      <input type="checkbox" defaultChecked={option.checked} />
                      <label className="text-sm">{option.label}</label>
                    </div>
                  ))}
                </div>
              </CardContent>
            </Card>

            <Card>
              <CardHeader>
                <CardTitle>Danger Zone</CardTitle>
              </CardHeader>
              <CardContent>
                <Button variant="destructive">Disconnect Wallet</Button>
              </CardContent>
            </Card>
          </TabsContent>
        </Tabs>
      </div>
    </main>
  )
}
