# DataExport
The data export engine supports exporting of data from RMT whenever a
client visits the RMT server to received updates or an initial registration
is performed.

With this implementation the implementer can decide to forward all client
data or specific data to some external service for data analysis for example.

## Usage
Place you implementation into /usr/share/rmt/engines/data_export/lib/data_export/handlers/ and implement the export_rmt_data function. The function takes no
arguments. Data to be exported is extracted from the RMT data base.
