function dt = convert_timestamp(ts)
    dt = datetime(ts, 'ConvertFrom', 'posixtime', 'TimeZone', 'UTC');
    dt.Format = 'HH:mm:ss.SSSS'; % Defines how it looks, but stays mathematical
end