function Zip-File( $ZipFilename, $SourceDirectory )
{
   Add-Type -Assembly System.IO.Compression.FileSystem
   $compressionLevel = [System.IO.Compression.CompressionLevel]::Optimal
   [System.IO.Compression.ZipFile]::CreateFromDirectory($SourceDirectory,
        $ZipFilename, $compressionLevel, $false)
}

Zip-File -SourceDirectory "G:\SRAS_CERTIFICATES\SRAS-51-93-6\310" -ZipFilename "C:\Scripts\Technology\CSE\SRAS-51-93-6-310.zip"