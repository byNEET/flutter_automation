import 'dart:io';
import './commons.dart' as commons;

String alias;
String keystorePath = "keys/keystore.jks";
String keyPass;
String keystorePass;
const String keyPropertiesPath = "./android/key.properties";

void androidSign() {
  generateKeystore();
  createKeyProperties();
  configureBuildConfig();
}

void generateKeystore() {
  String defDname =
      "CN=popupbits.com, OU=DD, O=Popup Bits Ltd., L=Kathmandu, S=Bagmati, C=NP";

  stdout.write("enter key alias: ");
  alias = stdin.readLineSync();

  stdout.write(
      "enter dname as (CN=popupbits.com, OU=DD, O=Popup Bits Ltd., L=Kathmandu, S=Bagmati, C=NP): ");
  String dname = stdin.readLineSync();
  if (dname.isEmpty) dname = defDname;
  stdout.write("key password: ");
  keyPass = stdin.readLineSync();
  stdout.write("keystore password: ");
  keystorePass = stdin.readLineSync();
  if (alias.isEmpty ||
      dname.isEmpty ||
      keyPass.isEmpty ||
      keystorePass.isEmpty) {
    stderr.writeln("All inputs that don't have default mentioned are required");
    return;
  }

  Directory keys = Directory("keys");
  if (!keys.existsSync()) {
    keys.createSync();
  }

  ProcessResult res = Process.runSync("keytool", [
    "-genkey",
    "-noprompt",
    "-alias",
    alias,
    "-dname",
    dname,
    "-keystore",
    keystorePath,
    "-storepass",
    keystorePass,
    "-keypass",
    keyPass,
    "-keyalg",
    "RSA",
    "-keysize",
    "2048",
    "-validity",
    "10000"
  ]);
  stdout.write(res.stdout);
  stderr.write(res.stderr);
  stdout.writeln("generated keystore with provided input");
}

void createKeyProperties() {
  commons.writeStringToFile(keyPropertiesPath, """storePassword=$keystorePass
keyPassword=$keyPass
keyAlias=$alias
storeFile=../../$keystorePath
""");
  stdout.writeln("key properties file created");
}

void configureBuildConfig() {
  List<String> buildfile = commons.getFileAsLines(commons.appBuildPath);
  buildfile = buildfile.map((line) {
    if (line.contains(RegExp("android.*{"))) {
      return """
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
            """;
    } else if (line.contains(RegExp("buildTypes.*{"))) {
      return """
  signingConfigs {
      release {
          keyAlias keystoreProperties['keyAlias']
          keyPassword keystoreProperties['keyPassword']
          storeFile file(keystoreProperties['storeFile'])
          storePassword keystoreProperties['storePassword']
      }
  }
  buildTypes {
            """;
    } else if (line.contains("signingConfig signingConfigs.debug")) {
      return "            signingConfig signingConfigs.release";
    } else {
      return line;
    }
  }).toList();

  commons.writeStringToFile(commons.appBuildPath, buildfile.join("\n"));
  stdout.writeln("configured release configs");
}
