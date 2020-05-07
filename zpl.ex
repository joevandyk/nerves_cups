defmodule PrintServer.Printers.ZPL do
  require Logger
  alias PrintServer.PrintJob
  alias PrintServer.Util

  def print(print_job) do
    Logger.info("Printing ZPL for print_job #{print_job.token}..")

    command = "lp -d zebra"
    Util.run_print_command(command, print_job.print_job_data)

    Logger.info("Printed ZPL for print_job #{print_job.token}..")

    {:ok, PrintJob.add_action_taken(print_job, "printed zpl")}
  end
end
