{ lib, ... }:

{
  # Profile constants that match shell script values
  profiles = {
    options = [
      "minimal"
      "desktop"
      "ouster"
    ];

    descriptions = {
      minimal = "CLI tools only";
      desktop = "includes GUI applications";
      ouster = "includes desktop + company tools";
    };

    default = "minimal";
  };
}
