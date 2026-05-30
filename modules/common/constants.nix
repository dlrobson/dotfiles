{ lib, ... }:

{
  # Profile constants that match shell script values
  profiles = {
    options = [
      "minimal"
      "desktop"
    ];

    descriptions = {
      minimal = "CLI tools only";
      desktop = "includes GUI applications";
    };

    default = "minimal";
  };
}
