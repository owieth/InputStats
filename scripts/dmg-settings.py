# dmgbuild settings for InputMetrics
# https://dmgbuild.readthedocs.io/en/latest/settings.html
import os

application = defines.get("app", "build/export/InputMetrics.app")
appname = os.path.basename(application)

files = [application]
symlinks = {"Applications": "/Applications"}

icon_locations = {
    appname: (180, 190),
    "Applications": (520, 190),
}

background = "assets/dmg-background.png"

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False

window_rect = ((200, 120), (700, 400))
default_view = "icon-view"
show_icon_preview = False

icon_size = 100
text_size = 1
