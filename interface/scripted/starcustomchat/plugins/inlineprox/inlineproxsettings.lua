require "/interface/scripted/starcustomchatsettings/settingsplugin.lua"

inlineprox = SettingsPluginClass:new(
  { name = "inlineprox" }
)


-- Settings
function inlineprox:init()
  self:_loadConfig()

  self.proximityRadius = root.getConfiguration("scc_inlineprox_radius") or self.proximityRadius
  widget.setSliderRange(self.layoutWidget .. ".sldProxRadius", 0, 240, 1)
  widget.setSliderValue(self.layoutWidget .. ".sldProxRadius", self.proximityRadius - 10)
  widget.setText(self.layoutWidget .. ".lblProxRadiusValue", self.proximityRadius)
end

function inlineprox:onLocaleChange()
  widget.setText(self.layoutWidget .. ".lblProxRadiusHint", starcustomchat.utils.getTranslation("settings.prox_radius"))
  widget.setText(self.layoutWidget .. ".titleText", starcustomchat.utils.getTranslation("settings.plugins.inlineprox"))
  widget.setText(self.layoutWidget .. ".lblRestrictingInfo",
    starcustomchat.utils.getTranslation("settings.plugins.restrict_description"))
end

function inlineprox:cursorOverride(screenPosition)
  if widget.active(self.layoutWidget) and (widget.inMember(self.layoutWidget .. ".sldProxRadius", screenPosition)
        or widget.inMember(self.layoutWidget .. ".lblProxRadiusValue", screenPosition)
        or widget.inMember(self.layoutWidget .. ".lblProxRadiusHint", screenPosition)) then
    if player.id() and world.entityPosition(player.id()) then
      starcustomchat.utils.drawCircle(world.entityPosition(player.id()), self.proximityRadius, "green")
      starcustomchat.utils.drawCircle(world.entityPosition(player.id()), self.proximityRadius * 0.25, "red")
      starcustomchat.utils.drawCircle(world.entityPosition(player.id()), (self.proximityRadius * 0.25) * 0.5, "yellow")
      starcustomchat.utils.drawCircle(world.entityPosition(player.id()), self.proximityRadius * 2, "blue")
    end
  end
end

function inlineprox:updateProxRadius(widgetName)
  self.proximityRadius = widget.getSliderValue(self.layoutWidget .. "." .. widgetName) + 10
  widget.setText(self.layoutWidget .. ".lblProxRadiusValue", self.proximityRadius)
  root.setConfiguration("scc_inlineprox_radius", self.proximityRadius)
  save()
end