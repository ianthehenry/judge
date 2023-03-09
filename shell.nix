with import <nixpkgs> {}; mkShell {
  nativeBuildInputs = [ python310Packages.cram ];
}
