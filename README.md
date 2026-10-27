# JuanFi vendo Telegram notifier

Telegram alerts for a JuanFi WiFi vendo running on a MikroTik router (such as the hAP lite):

| Alert | Example message | Triggered when |
|-------|-----------------|----------------|
| Login alert | `New connection: <voucher>`, MAC, IP | Someone connects to the hotspot |
| Sale alert | `Coins inserted: ₱5`, `Today's sales: ₱31` | Coins are inserted into the vendo |

> **Status:** written without access to a router, so test it with the steps below before relying on it.

## How it works

- **Does not modify JuanFi.** It never edits your hotspot user profiles or their on-login scripts. It only reads state and sends messages, so it cannot break JuanFi's voucher and expiry handling.
- **Login alert:** every 10 seconds, `login-alert` compares the active hotspot sessions with the previous check and reports new ones.
- **Sale alert:** every 10 seconds, `sale-alert` reads today's sales total from the vendo API and reports any increase as the amount of coins inserted.
- **Offline safe:** if the internet or Telegram is unreachable, alerts stay pending and are sent when it works again.

## Files

| File | Purpose |
|------|---------|
| `config.example.rsc` | Template for the `tg-notify` helper (bot token and chat ID) |
| `login-alert.rsc` | New-connection alert |
| `sale-alert.rsc` | Coin / sale alert |
| `.gitignore` | Keeps your real `config.rsc` out of git |

Requirements: RouterOS 6.49.x or v7 with the hotspot package, a JuanFi vendo reachable from the router, and a Telegram bot.

## Setup

### 1. Create the Telegram bot

1. In Telegram, open **@BotFather** and send `/newbot`. Copy the **bot token**.
2. Open a chat with your bot (or add it to a group) and send any message.
3. Get the chat ID from `https://api.telegram.org/bot<BOT_TOKEN>/getUpdates` (`message.chat.id`; group IDs are negative).

You can reuse an existing bot, but a dedicated bot or chat keeps vendo alerts separate from network alerts.

### 2. Install the Telegram helper

1. Copy `config.example.rsc` to `config.rsc` and replace `<BOT_TOKEN>` and `<CHAT_ID>`.
2. Upload `config.rsc` to the router (WinBox: **Files**) and run `/import file-name=config.rsc`.
3. Test it:

```routeros
:global tgMsg "Hello%20from%20the%20vendo"
/system script run tg-notify
```

### 3. Install the login alert

```routeros
/import file-name=login-alert.rsc
```

### 4. Install the sale alert

1. Find your vendo IP (JuanFi default is `172.217.28.1`). Edit `sale-alert.rsc` and replace `<VENDO-IP>`.
2. Check what the vendo API returns **before** importing:

```routeros
:put ([/tool fetch url="http://<VENDO-IP>/getSales" mode=http output=user as-value]->"data")
```

It should print a plain number (today's sales). If it prints something else, see Troubleshooting.

3. Import:

```routeros
/import file-name=sale-alert.rsc
```

Each file removes its previous version first, so you can edit and re-import safely.

## Testing

- **Login alert:** connect a phone to the vendo WiFi and log in. The alert should arrive within about 10 seconds.
- **Sale alert:** insert a coin. The alert should arrive within about 10 seconds with the amount.
- **Force a sale alert without a coin:** `:global lastSales 0`. The next check reports today's whole total as an alert.
- **Offline behaviour:** disconnect the ISP, connect a device, then reconnect the ISP. The pending alert should arrive once the internet is back.

## Notes and limits

- The first check after a reboot only learns the current state, so no alerts are sent for sessions that already exist or for sales that happened before.
- A session that starts and ends within 10 seconds can be missed. Lower the scheduler `interval` if you need faster checks.
- Several coins inserted within the same 10 seconds arrive as one message with the combined amount.
- If the sales total drops (new day or month rollover), the sale alert resets silently.

## Security

- The bot token is stored in the `tg-notify` script on the router. `/export` and backups include it, so do not share them. If it leaks, revoke it in @BotFather with `/revoke`.
- Keep real credentials only in `config.rsc`, which is git-ignored.
- By default `/tool fetch` does not verify certificates. To enable it, import the root CA of `api.telegram.org` on the router and add `check-certificate=yes` to the `fetch` line in `tg-notify`.

## Troubleshooting

- **Nothing arrives:** run `/log print where message~"tg-notify"`. Common causes are a wrong token or chat ID, never having messaged the bot, or no DNS or internet on the router.
- **"not enough permissions" in the log:** widen the script and scheduler policies (for example add `policy`) and import again.
- **`sale-alert: unexpected response`:** the vendo API does not return a plain number. Run the endpoint check from step 4 and open an issue with what it prints (hide any private data). The parser in `sale-alert.rsc` is one line and easy to adapt.
- **`sale-alert: could not read the vendo API`:** wrong `<VENDO-IP>`, or the vendo is off or unreachable from the router.
- **Login alerts show unexpected usernames:** the hotspot user is whatever JuanFi names the voucher or session.
