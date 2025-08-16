"use strict"
const key = "enabled"
const icon_on = "icons/toolbar-on.png"
const icon_off = "icons/toolbar-off.png"
const set_icon = (tab_id, en) => browser.browserAction.setIcon({
  tabId: tab_id,
  path: en ? icon_on : icon_off
})
const send = (tab_id, en) => browser.tabs.sendMessage(tab_id, {
  enabled: en
}).catch(() => {})
browser.runtime.onInstalled.addListener(() => browser.storage.local.set({
  [key]: true
}))
browser.browserAction.onClicked.addListener(async tab => {
  const v = await browser.storage.local.get({
    [key]: true
  })
  const en = !v[key]
  await browser.storage.local.set({
    [key]: en
  })
  await set_icon(tab.id, en)
  await send(tab.id, en)
})
browser.tabs.onActivated.addListener(async info => {
  const v = await browser.storage.local.get({
    [key]: true
  })
  await set_icon(info.tabId, v[key])
})
browser.tabs.onUpdated.addListener(async (tab_id, chg) => {
  if (chg.status === "complete") {
    const v = await browser.storage.local.get({
      [key]: true
    })
    await set_icon(tab_id, v[key])
    await send(tab_id, v[key])
  }
})
