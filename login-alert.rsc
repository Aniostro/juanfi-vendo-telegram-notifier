# login-alert.rsc
# Sends a Telegram message when someone connects to the vendo hotspot.
#
# How it works: every 10 seconds it compares the list of active hotspot sessions with the
# previous check. It does NOT touch your JuanFi user profiles or their on-login scripts,
# so it cannot interfere with JuanFi's own voucher and expiry handling.
#
# If the internet is down or Telegram fails, the alert stays pending and is retried on the
# next check, so no connection is lost from the alerts.
# Requires the tg-notify script from config.rsc.

/system scheduler remove [find name=login-alert-run]
/system script remove [find name=login-alert]

/system script add name=login-alert policy=ftp,read,write,test source={
  :global seenSessions
  :global tgMsg
  :global tgOk
  :local firstRun ([:typeof $seenSessions] != "array")
  :local current [:toarray ""]
  :local msg ""

  :foreach id in=[/ip hotspot active find] do={
    :local key [:tostr $id]
    :set ($current->$key) true
    :if (!$firstRun && [:typeof ($seenSessions->$key)] = "nothing") do={
      :local u [/ip hotspot active get $id user]
      :local ip [/ip hotspot active get $id address]
      :local mac [/ip hotspot active get $id mac-address]
      :set msg ($msg . "New%20connection:%20" . $u . "%0AMAC:%20" . $mac . "%0AIP:%20" . $ip . "%0A%0A")
    }
  }

  :if ($firstRun) do={
    # first run after boot: just learn who is already connected
    :set seenSessions $current
  } else={
    :if ([:len $msg] = 0) do={
      :set seenSessions $current
    } else={
      # only send when the internet is reachable; otherwise keep it pending
      :if ([/ping 1.1.1.1 count=1] > 0) do={
        :set tgMsg $msg
        /system script run tg-notify
        :if ($tgOk) do={ :set seenSessions $current }
      }
    }
  }
}

/system scheduler add name=login-alert-run interval=10s policy=ftp,read,write,test \
  on-event="/system script run login-alert"
