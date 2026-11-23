#!/usr/bin/python3
"""sni-watcher — StatusNotifierWatcher independente da waybar (bandeja do sistema: Discord, Steam, nm-applet...).

Problema que resolve: o watcher mora no processo que primeiro pediu o nome `org.kde.StatusNotifierWatcher`. Com uma
waybar por monitor (waybar-fullscreen.sh), quando a instancia dona e relancada (ex.: HDMI religado depois de
suspender) o watcher MORRE junto e a lista de icones some. Apps Electron (Discord) so se registram uma vez, entao o
icone nao volta ate reiniciar o app. Este servico (waybar-sni-watcher.service) e dono do nome SEMPRE e sobrevive aos
relancamentos: as waybars viram apenas "hosts" e releem a lista.

Implementa org.kde.StatusNotifierWatcher (RegisterStatusNotifierItem/Host, propriedades, sinais) e remove itens e
hosts quando o dono deles some do barramento. Usa /usr/bin/python3 (python-gobject).
"""
import sys
import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

NAME, PATH, IFACE = "org.kde.StatusNotifierWatcher", "/StatusNotifierWatcher", "org.kde.StatusNotifierWatcher"
XML = """
<node><interface name="org.kde.StatusNotifierWatcher">
  <method name="RegisterStatusNotifierItem"><arg type="s" name="service" direction="in"/></method>
  <method name="RegisterStatusNotifierHost"><arg type="s" name="service" direction="in"/></method>
  <property name="RegisteredStatusNotifierItems" type="as" access="read"/>
  <property name="IsStatusNotifierHostRegistered" type="b" access="read"/>
  <property name="ProtocolVersion" type="i" access="read"/>
  <signal name="StatusNotifierItemRegistered"><arg type="s"/></signal>
  <signal name="StatusNotifierItemUnregistered"><arg type="s"/></signal>
  <signal name="StatusNotifierHostRegistered"/>
  <signal name="StatusNotifierHostUnregistered"/>
</interface></node>"""

items = {}   # "bus/path" -> dono (nome unico) ; hosts: nome -> watch id
hosts = {}
conn = None


def emit(sig, params=None):
    conn.emit_signal(None, PATH, IFACE, sig, params)


def watch(owner, on_gone):
    return Gio.bus_watch_name_on_connection(conn, owner, Gio.BusNameWatcherFlags.NONE, None,
                                            lambda c, n: on_gone(n))


def item_gone(owner):
    for key in [k for k, o in items.items() if o == owner]:
        del items[key]
        emit("StatusNotifierItemUnregistered", GLib.Variant("(s)", (key,)))
    conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                     GLib.Variant("(sa{sv}as)", (IFACE, {}, ["RegisteredStatusNotifierItems"])))


def host_gone(name):
    hosts.pop(name, None)
    if not hosts:
        emit("StatusNotifierHostUnregistered")


def on_method(c, sender, path, iface, method, params, inv):
    arg = params.unpack()[0]
    if method == "RegisterStatusNotifierItem":
        key = (sender + arg) if arg.startswith("/") else (arg + "/StatusNotifierItem")
        if key not in items:
            items[key] = sender if arg.startswith("/") else arg
            owners = {sender, items[key]}
            for o in owners:
                watch(o, item_gone)
            emit("StatusNotifierItemRegistered", GLib.Variant("(s)", (key,)))
            conn.emit_signal(None, PATH, "org.freedesktop.DBus.Properties", "PropertiesChanged",
                             GLib.Variant("(sa{sv}as)", (IFACE, {}, ["RegisteredStatusNotifierItems"])))
    else:  # RegisterStatusNotifierHost
        if arg not in hosts:
            hosts[arg] = watch(arg, host_gone)
            emit("StatusNotifierHostRegistered")
    inv.return_value(None)


def on_get(c, sender, path, iface, prop):
    if prop == "RegisteredStatusNotifierItems":
        return GLib.Variant("as", sorted(items))
    if prop == "IsStatusNotifierHostRegistered":
        return GLib.Variant("b", bool(hosts))
    return GLib.Variant("i", 0)


def on_bus(c, name):
    global conn
    conn = c
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    c.register_object(PATH, node.interfaces[0], on_method, on_get, None)


def on_lost(c, name):
    sys.exit("sni-watcher: nao foi possivel assumir %s (ja existe um dono?)" % NAME)


Gio.bus_own_name(Gio.BusType.SESSION, NAME, Gio.BusNameOwnerFlags.DO_NOT_QUEUE, on_bus, None, on_lost)
GLib.MainLoop().run()
