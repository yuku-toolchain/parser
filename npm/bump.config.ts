import { defineConfig } from "bumpp"

export default defineConfig({
  commit: "npm %s",
  confirm: false,
  release: "patch"
});
