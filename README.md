# EnclaveKit demo

The iOS app that tests the [EnclaveKit SDK](https://github.com/ikaros-nb/enclavekit-swift) on real iPhones and runs the demo. Not a product.

It covers the whole v1 on devnet:

- create a wallet whose key lives in the Secure Enclave;
- receive SOL on the vault, and send it behind Face ID, Touch ID or the passcode;
- move the wallet to another iPhone at once, and back;
- name a second iPhone as guardian;
- propose, cancel and confirm a recovery;
- start over.

## Setup

What it takes:
- Xcode 27.
- Two iPhones running iOS 27, or an iPhone and an iPad. The second one receives the wallet, then guards it.
- A Mac on the same Wi-Fi, running the Kora relayer.

The three repositories sit side by side: the Xcode project takes the SDK as a local package at `../enclavekit-swift`.

```
EnclaveKit/
├── enclavekit-anchor/      program and Kora config
├── enclavekit-swift/       SDK
└── enclavekit-demo-ios/    this app
```

1. **Start Kora on the Mac.** See [Relayer](https://github.com/ikaros-nb/enclavekit-anchor#relayer) in enclavekit-anchor. The iPhones reach it over Wi-Fi: the Mac's firewall has to let port 8080 in.
2. **Edit `EnclaveKitDemo/DemoConfig.swift`,** the only file that belongs to a given Mac:
   - `enclaveKit`: Kora's URL, the Mac's Bonjour name and port 8080;
   - `recipient`: the CLI wallet that funds the vault, where the demo sends SOL back. Send and Close wallet prefill it.
3. **Open `EnclaveKit demo.xcodeproj`,** scheme `EnclaveKitDemo`. Pick your team under Signing, then run on each iPhone.
4. **Allow access at first launch.** The app asks for the local network, to reach Kora, and for the camera, to scan QR codes.

The simulator shows the screens but cannot make the key: the Secure Enclave there refuses the access control it needs.

## Screens

| Screen | What it does |
|---|---|
| Enroll | Makes the device key. Warns that without a guardian, a lost iPhone is a lost wallet. |
| Wallet | The vault's address and balance, the status, a recovery to cancel or to confirm. Once the wallet moved away, Show wallet ID. Pull down to refresh. |
| Send | Recipient, amount or Send all, then Review. |
| Approve | The sheet of every action: what is signed, addresses in full, the fee ceiling, then Authorize. |
| Guardians | Adds a guardian by scanning its device key, removes one by swiping. Shows the wallet ID for guardians to keep. |
| Guarding | The wallets this iPhone guards. Shows its device key, and adds a wallet by scanning its ID. |
| Guarded wallet | Start recovery: scan the new iPhone's key, then show it the wallet ID. Forget this wallet. |
| Move to another iPhone | Scans the new iPhone's key, then Authorize: the wallet moves at once. Then shows the wallet ID for the new iPhone to scan. |
| Recover a wallet | On the new iPhone: shows its key to the iPhone that signs for the wallet, or to a guardian if that one is lost. Then scans the wallet ID. |
| Close wallet | Sends everything out, closes the wallet, deletes the key: back to Enroll. |
| Delete device key | The key only. The wallet stays on-chain for a guardian to move: this is how the demo loses an iPhone. |

## Demo run

iPhone A is the owner. iPhone B receives the wallet, then guards it. On devnet the recovery delay is one minute.

**Wallet and send**
1. A: Create wallet. Copy the address, then fund it from any devnet wallet:
   ```bash
   solana transfer <address> 1 --allow-unfunded-recipient -u devnet
   ```
2. A: Send SOL, Review, Authorize. View in Explorer.

**Move to iPhone B and back**

B's own wallet must never act: an iPhone that signs for a wallet cannot take on another.

3. B: Create wallet if it has none. Recover a wallet shows its key.
4. A: Move to another iPhone, scan B's key, Authorize. A then shows the wallet ID, and its status turns to Moved to another key.
5. B: Scan wallet ID. B signs at once: same address, same balance. Send SOL to prove it.
6. A: Recover a wallet shows its key. B: Move to another iPhone, scan A's key, Authorize.
7. A: Scan the wallet ID B shows. A signs again.

B now shows A's wallet as Moved to another key. Its key still guards.

**Guardian**

8. B: Guarding, Show device key.
9. A: Guardians, Add guardian, scan B's key, Authorize. Then Show wallet ID.
10. B: Guarding, Guard a wallet, scan A's wallet ID.

**Cancel a recovery**

11. B: open A's wallet, Start recovery, then scan or paste another device's key. Authorize.
12. A: Recovery in progress shows up on the wallet. Cancel recovery, Authorize.

**Lose iPhone A**

13. A: Delete device key, then Create wallet. Recover a wallet shows its new key.
14. B: open A's wallet, Start recovery, scan A's new key, Authorize. Then Show wallet ID.
15. A: Scan wallet ID. One minute later, Confirm recovery: the relayer pays, nothing to approve.
16. A: Send SOL again. The new key signs for the same wallet.

**Start over**

17. A: Close wallet, Authorize, Done. Everything goes back to `recipient`, and A is back on Enroll.
18. B: Guarding, A's wallet, Forget this wallet. B keeps its key for the next run.

## Code

- `WalletModel` holds the state and the SDK calls behind the buttons. Only `RootView` sees it.
- Each screen takes plain values and closures, so its preview runs without a Secure Enclave.
- `RootView` pushes the screens of the `Screen` enum, and presents the Approve sheet for any `ActionRequest`.
