# There's gotta be a better way to do this.
# We want to poll for USB printers (currently, Zebra and HP printers)
# and add them to CUPS. Seems like something else should take care of this for us,
# but couldn't find anything.
defmodule PrintServer.Device.DetectPrinters do
  use GenServer
  require Logger

  defmodule Printer do
    defstruct [:printer_type, :device_string, :printer_name]
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    state = update_printers(state)
    schedule_work()
    {:ok, state}
  end

  def handle_info(:work, state) do
    state = update_printers(state)
    schedule_work()
    {:noreply, state}
  end

  defp schedule_work() do
    Process.send_after(self(), :work, 10_000)
  end

  def update_printers(state) do
    printers = usb_printers()

    # Careful - no unit tests yet for any of the following, but it's important.

    # If there's any change in the detected printers, update all the printers in CUPS
    if state != printers do
      Enum.each(printers, fn printer -> update_printer(printer) end)
    end

    printers
  end

  def usb_printers() do
    usb_files = "/sys/bus/usb/devices/*/product"

    Enum.map(Path.wildcard(usb_files), fn filename ->
      directory = Path.dirname(filename)
      {:ok, manufacturer} = File.read(Path.join(directory, "manufacturer"))
      {:ok, product} = File.read(Path.join(directory, "product"))
      manufacturer = String.trim(manufacturer)
      product = String.trim(product)

      # So, I don't get this at all.
      #
      # The 6790 has a product name as reported by USB as `OfficeJet Pro 6790`
      # and so the usb device string is usb://HP/OfficeJet Pro 6790. That all works fine.
      #
      # However, the 8210 has a product name reported by USB as `HP OfficeJet Pro 8210`.
      # But, the printer doesn't seem to respond to a device string like
      # usb://HP/HP OfficeJet Pro 8210. Instead, it has to be usb://HP/OfficeJet Pro 8210
      # So.. we're just going to remove 'HP' from the start of the product names here.
      product = List.last(Regex.split(~r/^HP /, product))

      device_string = "usb://#{URI.encode(manufacturer)}/#{URI.encode(product)}"

      if printer_type(device_string) do
        %Printer{printer_type: printer_type(device_string), device_string: device_string, printer_name: product}
      end
    end)
    |> Enum.filter(fn printer -> printer != nil end)
  end

  # Updates the printer information in CUPS.
  def update_printer(printer) do
    lp_options = ["-p", printer.printer_type, "-E", "-v", printer.device_string]

    lp_options = if printer.printer_type == "hp" do
      # HP printers use this PPD file. Seems to work on a few different ones.
      lp_options ++ ["-m", "hp-officejet_pro_6970.ppd"]
    else
      lp_options
    end

    Logger.info("Adding Printer: `lpadmin #{Enum.join(lp_options, " ")}`")
    System.cmd("lpadmin", lp_options)
  end

  # Map device strings to known printer names.
  def printer_type(device) do
    cond do
      String.contains?(device, "Zebra") -> "zebra"
      String.contains?(device, "OfficeJet") -> "hp"
      true -> nil
    end
  end
end
