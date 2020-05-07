# There's gotta be a better way to do this.
# The usb devices are setup with only root being able to read/write to them.
# CUPS requires that print jobs run under a non-root process.
# Ideally, nerves or something would have someway to automatically change the permissions of USB devices.
# `udev` (i think) is usually tasked with that responsibility, but nerves doesn't run that by default.
# So, as a quick workaround, every so often, update the permissions of all usb devices.
defmodule PrintServer.Device.FixStupidPermissions do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_work()
    {:ok, state}
  end

  def handle_info(:work, state) do
    spawn(fn -> update_permissions() end)
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 1_000)
  end

  def update_permissions do
    files = Path.wildcard("/dev/bus/usb/001/*")

    for file <- files do
      File.chmod(file, 0o666)
    end

    # Ensure everyone can write to /tmp and /var/spool, cups was reporting permission errors
    File.chmod "/tmp", 0o777
    File.chmod "/var/spool", 0o777
  end
end
