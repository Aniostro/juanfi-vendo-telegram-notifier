# sale-alert.rsc
# Sends a Telegram message when coins are inserted into the vendo.
#
# How it works: every 10 seconds it reads today's sales total from the vendo (NodeMCU) API and
# compares it with the previous reading. An increase means coins were inserted, and the
# difference is the amount. Coins inserted within the same 10 seconds are reported together.
#
# BEFORE IMPORTING: replace <VENDO-IP> with your vendo's IP (JuanFi default is 172.217.28.1,
# check yours). Then run the endpoint check in the README. This script expects /getSales to
# return a plain number; if yours returns something else, see Troubleshooting in the README.
#
# Requires the tg-notify script from config.rsc.

/system scheduler remove [find name=sale-alert-run]
/system script remove [find name=sale-alert]

/system script add name=sale-alert policy=ftp,read,write,test source={
  :global lastSales
  :global tgMsg
  :global tgOk
  :local sales
  :do {
    :local r [/tool fetch url="http://<VENDO-IP>/getSales" mode=http output=user as-value]
    :set sales [:tonum ($r->"data")]
  } on-error={ :log warning "sale-alert: could not read the vendo API" }

  :if ([:typeof $sales] = "num") do={
    :if ([:typeof $lastSales] != "num") do={
      # first reading after boot: just learn the current total
      :set lastSales $sales
    } else={
      # total went down: new day / month rollover or counter reset, start over
      :if ($sales < $lastSales) do={ :set lastSales $sales }
      :if ($sales > $lastSales) do={
        :local paid ($sales - $lastSales)
        :set tgMsg ("Coins%20inserted:%20%E2%82%B1" . $paid . "%0AToday%27s%20sales:%20%E2%82%B1" . $sales)
        # only send when the internet is reachable; otherwise keep it pending
        :if ([/ping 1.1.1.1 count=1] > 0) do={
          /system script run tg-notify
          :if ($tgOk) do={ :set lastSales $sales }
        }
      }
    }
  } else={
    :log warning "sale-alert: unexpected response from the vendo API (expected a number)"
  }
}

/system scheduler add name=sale-alert-run interval=10s policy=ftp,read,write,test \
  on-event="/system script run sale-alert"
