import fs from 'fs'
import path from 'path'

export function ensureOhosPluginList(flutterProjectPath: string) {
  const dependencyFile = path.join(flutterProjectPath, '.flutter-plugins-dependencies')
  if (!fs.existsSync(dependencyFile)) {
    return
  }

  const content = fs.readFileSync(dependencyFile, 'utf-8')
  const dependencies = JSON.parse(content)
  dependencies.plugins = dependencies.plugins ?? {}
  dependencies.plugins.ohos = dependencies.plugins.ohos ?? []
  fs.writeFileSync(dependencyFile, JSON.stringify(dependencies))
}
