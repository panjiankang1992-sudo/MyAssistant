import path from 'path'
import { injectNativeModules } from 'flutter-hvigor-plugin';
import { ensureOhosPluginList } from './flutter_plugin_compat';

ensureOhosPluginList(path.dirname(__dirname))
injectNativeModules(__dirname, path.dirname(__dirname))
