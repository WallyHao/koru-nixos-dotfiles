# Persistent system journal size limits.
{
  # Cap the journal at 100M (default is 10% of the root disk) to bound disk use
  # and SSD write wear; kept on disk so past boots stay queryable.
  services.journald.settings.Journal = {
    SystemMaxUse = "100M";
    SystemMaxFileSize = "16M";
  };
}
