# config.example.rsc
# Copy this file to config.rsc, fill in your real values, then import it on the router.
# config.rsc is git-ignored. Never commit your real bot token.
#
# Creates the "tg-notify" script used by login-alert and sale-alert.
# Message text must be URL-encoded: %20 = space, %0A = new line.
# Targets RouterOS 6.49.x (hAP lite running JuanFi). Also works on v7.

/system script remove [find name=tg-notify]
/system script add name=tg-notify policy=ftp,read,write,test source={
  :global tgMsg
  :global tgOk
  :set tgOk false
  :local token "<BOT_TOKEN>"
  :local chat "<CHAT_ID>"
  :do {
    /tool fetch mode=https keep-result=no http-method=post \
      url=("https://api.telegram.org/bot" . $token . "/sendMessage") \
      http-data=("chat_id=" . $chat . "&text=" . $tgMsg)
    :set tgOk true
  } on-error={
    :set tgOk false
    :log warning "tg-notify: send failed"
  }
}
