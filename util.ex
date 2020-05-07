defmodule PrintServer.Util do
  def run_print_command(print_command_string, print_job_data) do
    if print_job_data do
      path = create_tempfile(print_job_data)

      case System.cmd("sh", ["-c", "#{print_command_string} #{path}"]) do
        {_, 0} -> true
        {_, exit_status} -> raise "#{print_command_string} failed with #{exit_status}"
      end
    end
  end

  def create_tempfile(print_job_data) do
    {:ok, path} = Briefly.create()
    File.write!(path, print_job_data)
    path
  end
end
