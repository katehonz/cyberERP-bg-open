defmodule CyberCore.DocumentProcessing.PdfMerger do
  @moduledoc """
  PDF merger utility за обединяване на множество PDF файлове.

  Използва ghostscript (gs) command line tool.

  Изисква ghostscript да е инсталиран:
  - Ubuntu/Debian: apt-get install ghostscript
  - macOS: brew install ghostscript
  """

  require Logger

  @doc """
  Обединява списък от PDF файлове в един.

  ## Parameters
  - `input_files` - списък от пътища към PDF файлове
  - `output_file` - път към изходния обединен PDF

  ## Options
  - `:compression` - compression quality (:default, :screen, :ebook, :printer, :prepress)

  ## Returns
  - `{:ok, output_file}` - успешно обединяване
  - `{:error, reason}` - грешка
  """
  def merge(input_files, output_file, opts \\ []) when is_list(input_files) do
    if length(input_files) == 0 do
      {:error, "No input files provided"}
    else
      do_merge_with_ghostscript(input_files, output_file, opts)
    end
  end

  @doc """
  Обединява файлове по батчове.

  ## Parameters
  - `input_files` - списък от пътища към PDF файлове
  - `output_dir` - директория за изходните файлове
  - `batch_size` - брой файлове на batch (default: 10)

  ## Returns
  - `{:ok, merged_files}` - списък с пътища към обединените файлове
  - `{:error, reason}` - грешка
  """
  def merge_batches(input_files, output_dir, batch_size \\ 10) do
    input_files
    |> Enum.chunk_every(batch_size)
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {batch, index}, {:ok, acc} ->
      output_file = Path.join(output_dir, "merged_batch_#{index + 1}.pdf")

      case merge(batch, output_file) do
        {:ok, file} ->
          {:cont, {:ok, [file | acc]}}

        {:error, reason} ->
          {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, files} -> {:ok, Enum.reverse(files)}
      error -> error
    end
  end

  # Private functions

  defp do_merge_with_ghostscript(input_files, output_file, opts) do
    compression = Keyword.get(opts, :compression, :default)
    quality = compression_to_quality(compression)

    # Ghostscript команда за обединяване
    args = [
      "-dBATCH",
      "-dNOPAUSE",
      "-q",
      "-sDEVICE=pdfwrite",
      "-dPDFSETTINGS=/#{quality}",
      "-sOutputFile=#{output_file}"
      | input_files
    ]

    case System.cmd("gs", args, stderr_to_stdout: true) do
      {_output, 0} ->
        Logger.info("Successfully merged #{length(input_files)} PDF files into #{output_file}")
        {:ok, output_file}

      {error_output, exit_code} ->
        Logger.error("Ghostscript merge failed with exit code #{exit_code}: #{error_output}")
        {:error, "PDF merge failed: #{error_output}"}
    end
  rescue
    error ->
      Logger.error("PDF merge error: #{inspect(error)}")
      {:error, "PDF merge failed: #{inspect(error)}"}
  end

  defp compression_to_quality(:screen), do: "screen"
  defp compression_to_quality(:ebook), do: "ebook"
  defp compression_to_quality(:printer), do: "printer"
  defp compression_to_quality(:prepress), do: "prepress"
  defp compression_to_quality(_), do: "default"

  @doc """
  Проверява дали ghostscript е инсталиран.
  """
  def ghostscript_available? do
    case System.cmd("which", ["gs"], stderr_to_stdout: true) do
      {path, 0} when byte_size(path) > 0 -> true
      _ -> false
    end
  rescue
    _ -> false
  end

  @doc """
  Вземане на информация за PDF файл (брой страници).
  """
  def get_page_count(pdf_file) do
    args = [
      "-dBATCH",
      "-dNOPAUSE",
      "-q",
      "-sDEVICE=bbox",
      pdf_file
    ]

    case System.cmd("gs", args, stderr_to_stdout: true) do
      {output, 0} ->
        # Брои колко пъти се среща "%%HiResBoundingBox"
        count =
          output
          |> String.split("\n")
          |> Enum.count(&String.contains?(&1, "%%HiResBoundingBox"))

        {:ok, count}

      {error, _} ->
        {:error, "Failed to get page count: #{error}"}
    end
  rescue
    error ->
      {:error, "Failed to get page count: #{inspect(error)}"}
  end

  @doc """
  Извлича страници от PDF.

  ## Parameters
  - `input_file` - входен PDF файл
  - `output_file` - изходен PDF файл
  - `first_page` - първа страница за извличане
  - `last_page` - последна страница за извличане
  """
  def extract_pages(input_file, output_file, first_page, last_page) do
    args = [
      "-dBATCH",
      "-dNOPAUSE",
      "-q",
      "-sDEVICE=pdfwrite",
      "-dFirstPage=#{first_page}",
      "-dLastPage=#{last_page}",
      "-sOutputFile=#{output_file}",
      input_file
    ]

    case System.cmd("gs", args, stderr_to_stdout: true) do
      {_output, 0} ->
        {:ok, output_file}

      {error_output, exit_code} ->
        Logger.error("Page extraction failed with exit code #{exit_code}: #{error_output}")
        {:error, "Page extraction failed: #{error_output}"}
    end
  rescue
    error ->
      {:error, "Page extraction failed: #{inspect(error)}"}
  end
end
