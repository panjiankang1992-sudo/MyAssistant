
import common from '@ohos.app.ability.common';
import Want from '@ohos.app.ability.Want';
import notificationManager from '@ohos.notificationManager';
import { BusinessError } from '@ohos.base';
import preferences from '@ohos.data.preferences';
import fs from '@ohos.file.fs';
import fileUri from '@ohos.file.fileuri';
import picker from '@ohos.file.picker';
import photoAccessHelper from '@ohos.file.photoAccessHelper';
import {
  FlutterAbility,
  FlutterEngine,
  MethodCall,
  MethodChannel,
  MethodResult
} from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';

const PERMISSIONS_CHANNEL = 'my_assistant/permissions';
const TODO_REMINDERS_CHANNEL = 'my_assistant/todo_reminders';
const FILE_PICKER_CHANNEL = 'my_assistant/file_picker';
const APP_LAUNCHER_CHANNEL = 'my_assistant/app_launcher';
const CALENDAR_CHANNEL = 'my_assistant/calendar';
const SMS_CHANNEL = 'my_assistant/sms';
const LOCAL_STORE_CHANNEL = 'my_assistant/local_store';
const SETTINGS_BUNDLE = 'com.huawei.hmos.settings';
const SETTINGS_ABILITY = 'com.huawei.hmos.settings.MainAbility';
const APPLICATION_INFO_URI = 'application_info_entry';

interface PickedFilePayload {
  name: string;
  path: string;
  size: number;
  sourceUri: string;
}

interface LaunchableAppPayload {
  platform: string;
  id: string;
  label: string;
  subtitle: string;
  bundleName?: string;
  abilityName?: string;
  action?: string;
  uri?: string;
  type?: string;
}

class AssistantMethodHandler {
  private context: common.UIAbilityContext;
  private channelName: string;

  constructor(context: common.UIAbilityContext, channelName: string) {
    this.context = context;
    this.channelName = channelName;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'openPermissionSettings':
        this.replyWith(result, this.openPermissionSettings(call));
        break;
      case 'openAuthorizationSettings':
      case 'openAppSettings':
        this.replyWith(result, this.openApplicationInfoSettings());
        break;
      case 'ensureNotificationPermission':
        this.replyWith(result, this.openNotificationSettings());
        break;
      default:
        result.notImplemented();
    }
  }

  private async openPermissionSettings(call: MethodCall): Promise<void> {
    const target = call.argument('target') as string | null;
    if (target === 'notifications') {
      await this.openNotificationSettings();
      return;
    }
    await this.openApplicationInfoSettings();
  }

  private async openApplicationInfoSettings(): Promise<void> {
    const bundleName = this.context.abilityInfo.bundleName;
    const want: Want = {
      bundleName: SETTINGS_BUNDLE,
      abilityName: SETTINGS_ABILITY,
      uri: APPLICATION_INFO_URI,
      parameters: {
        pushParams: bundleName,
      },
    };
    await this.context.startAbility(want);
  }

  private async openNotificationSettings(): Promise<void> {
    try {
      await notificationManager.openNotificationSettings(this.context);
    } catch (_) {
      await this.openApplicationInfoSettings();
    }
  }

  private replyWith(result: MethodResult, task: Promise<void>): void {
    task
      .then(() => result.success(true))
      .catch((error: BusinessError) => {
        result.error(
          `${this.channelName}_error`,
          error.message ?? 'Failed to open settings',
          error.code ?? null
        );
      });
  }
}

class AssistantFilePickerHandler {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'pickImages':
        this.replyWith(result, this.pickImages(call));
        break;
      case 'pickFiles':
        this.replyWith(result, this.pickFiles(call));
        break;
      case 'openFile':
        this.replyWithOpen(result, this.openFile(call));
        break;
      default:
        result.notImplemented();
    }
  }

  private async pickImages(call: MethodCall): Promise<Array<PickedFilePayload>> {
    const options = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = this.maxSelectNumber(call);
    options.isOriginalSupported = true;

    const photoViewPicker = new photoAccessHelper.PhotoViewPicker();
    const selected = await photoViewPicker.select(options);
    return this.copyUrisToSandbox(selected.photoUris ?? [], 'image');
  }

  private async pickFiles(call: MethodCall): Promise<Array<PickedFilePayload>> {
    const options = new picker.DocumentSelectOptions();
    options.maxSelectNumber = this.maxSelectNumber(call);
    const documentViewPicker = new picker.DocumentViewPicker(this.context);
    const selected = await documentViewPicker.select(options);
    return this.copyUrisToSandbox(selected ?? [], 'file');
  }

  private async openFile(call: MethodCall): Promise<void> {
    const path = (call.argument('path') as string | null)?.trim() ?? '';
    if (path.length === 0) {
      throw new Error('Missing file path');
    }
    const uri = fileUri.getUriFromPath(path);
    const rawMimeType = (call.argument('mimeType') as string | null)?.trim() ?? '';
    const want: Want = {
      action: 'ohos.want.action.viewData',
      uri: uri,
      type: rawMimeType.length > 0 ? rawMimeType : this.mimeTypeForPath(path),
    };
    await this.context.startAbility(want);
  }

  private maxSelectNumber(call: MethodCall): number {
    const raw = call.argument('maxSelectNumber') as Object | null;
    const value = typeof raw === 'number' ? raw : 1;
    return Math.max(1, Math.min(Math.floor(value), 50));
  }

  private async copyUrisToSandbox(
    uris: Array<string>,
    kind: string
  ): Promise<Array<PickedFilePayload>> {
    const targetDir = `${this.context.cacheDir}/myassistant_picker`;
    fs.mkdirSync(targetDir, true);

    const picked: Array<PickedFilePayload> = [];
    for (let i = 0; i < uris.length; i++) {
      const sourceUri = uris[i];
      const fileName = this.displayNameForUri(sourceUri, kind, i);
      const localName = `${Date.now()}_${i}_${this.safeFileName(fileName, kind, i)}`;
      const localPath = `${targetDir}/${localName}`;
      await this.copyUriToPath(sourceUri, localPath);
      const stat = await fs.stat(localPath);
      picked.push({
        name: fileName,
        path: localPath,
        size: stat.size,
        sourceUri: sourceUri,
      });
    }
    return picked;
  }

  private async copyUriToPath(sourceUri: string, localPath: string): Promise<void> {
    let source: fs.File | null = null;
    let target: fs.File | null = null;
    try {
      source = await fs.open(sourceUri, fs.OpenMode.READ_ONLY);
      target = await fs.open(
        localPath,
        fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC
      );
      await fs.copyFile(source.fd, target.fd);
    } finally {
      if (source != null) {
        fs.closeSync(source);
      }
      if (target != null) {
        fs.closeSync(target);
      }
    }
  }

  private displayNameForUri(sourceUri: string, kind: string, index: number): string {
    try {
      const name = new fileUri.FileUri(sourceUri).name;
      if (name.length > 0) {
        return this.decodeUriPart(name);
      }
    } catch (_) {
    }
    const withoutQuery = sourceUri.split('?')[0].split('#')[0];
    const slashIndex = withoutQuery.lastIndexOf('/');
    const fallback = slashIndex >= 0 ? withoutQuery.substring(slashIndex + 1) : withoutQuery;
    if (fallback.length > 0) {
      return this.decodeUriPart(fallback);
    }
    return kind === 'image' ? `image_${index}.jpg` : `attachment_${index}`;
  }

  private safeFileName(fileName: string, kind: string, index: number): string {
    const fallback = kind === 'image' ? `image_${index}.jpg` : `attachment_${index}`;
    const cleaned = fileName
      .replace(/[\\/:*?"<>|]/g, '_')
      .replace(/\s+/g, '_')
      .trim();
    return cleaned.length > 0 ? cleaned : fallback;
  }

  private decodeUriPart(value: string): string {
    try {
      return decodeURIComponent(value);
    } catch (_) {
      return value;
    }
  }

  private mimeTypeForPath(path: string): string {
    const lower = path.toLowerCase();
    if (lower.endsWith('.png')) {
      return 'image/png';
    }
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.gif')) {
      return 'image/gif';
    }
    if (lower.endsWith('.webp')) {
      return 'image/webp';
    }
    if (lower.endsWith('.heic')) {
      return 'image/heic';
    }
    if (lower.endsWith('.mp3')) {
      return 'audio/mpeg';
    }
    if (lower.endsWith('.m4a')) {
      return 'audio/mp4';
    }
    if (lower.endsWith('.wav')) {
      return 'audio/wav';
    }
    if (lower.endsWith('.pdf')) {
      return 'application/pdf';
    }
    if (lower.endsWith('.txt')) {
      return 'text/plain';
    }
    return 'application/octet-stream';
  }

  private replyWith(
    result: MethodResult,
    task: Promise<Array<PickedFilePayload>>
  ): void {
    task
      .then((files) => result.success(files))
      .catch((error: BusinessError) => {
        result.error(
          'file_picker_error',
          error.message ?? 'Failed to pick files',
          error.code ?? null
        );
      });
  }

  private replyWithOpen(result: MethodResult, task: Promise<void>): void {
    task
      .then(() => result.success(true))
      .catch((error: BusinessError) => {
        result.error(
          'file_open_error',
          error.message ?? 'Failed to open file',
          error.code ?? null
        );
      });
  }
}

class AssistantAppLauncherHandler {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'listApps':
        result.success(this.launchableApps());
        break;
      case 'openApp':
        this.replyWithOpen(result, this.openApp(call));
        break;
      default:
        result.notImplemented();
    }
  }

  private launchableApps(): Array<LaunchableAppPayload> {
    const systemApps: Array<LaunchableAppPayload> = [
      {
        platform: 'ohos',
        id: SETTINGS_BUNDLE,
        label: '设置',
        subtitle: SETTINGS_BUNDLE,
        bundleName: SETTINGS_BUNDLE,
        abilityName: SETTINGS_ABILITY,
      },
      {
        platform: 'ohos',
        id: 'com.huawei.hmos.calendar',
        label: '日历',
        subtitle: 'com.huawei.hmos.calendar',
        bundleName: 'com.huawei.hmos.calendar',
        abilityName: 'MainAbility',
      },
      {
        platform: 'ohos',
        id: 'com.huawei.hmos.contacts',
        label: '电话 / 联系人',
        subtitle: 'com.huawei.hmos.contacts',
        bundleName: 'com.huawei.hmos.contacts',
        abilityName: 'MainAbility',
      },
      {
        platform: 'ohos',
        id: 'com.huawei.hmos.mms',
        label: '信息',
        subtitle: 'com.huawei.hmos.mms',
        bundleName: 'com.huawei.hmos.mms',
        abilityName: 'MainAbility',
      },
      {
        platform: 'ohos',
        id: 'com.huawei.hmos.photos',
        label: '图库',
        subtitle: 'com.huawei.hmos.photos',
        bundleName: 'com.huawei.hmos.photos',
        abilityName: 'MainAbility',
      },
      {
        platform: 'ohos',
        id: 'com.huawei.hmos.filemanager',
        label: '文件管理',
        subtitle: 'com.huawei.hmos.filemanager',
        bundleName: 'com.huawei.hmos.filemanager',
        abilityName: 'MainAbility',
      },
      {
        platform: 'ohos',
        id: 'com.huawei.hmos.browser',
        label: '浏览器',
        subtitle: 'com.huawei.hmos.browser',
        bundleName: 'com.huawei.hmos.browser',
        abilityName: 'MainAbility',
      },
      {
        platform: 'ohos',
        id: 'com.huawei.hmos.camera',
        label: '相机',
        subtitle: 'com.huawei.hmos.camera',
        bundleName: 'com.huawei.hmos.camera',
        abilityName: 'MainAbility',
      },
    ];
    const commonApps: Array<LaunchableAppPayload> = [
      {
        platform: 'ohos',
        id: 'com.tencent.wechat',
        label: '微信',
        subtitle: 'com.tencent.wechat',
        bundleName: 'com.tencent.wechat',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.tencent.mm',
        label: '微信（兼容）',
        subtitle: 'com.tencent.mm',
        bundleName: 'com.tencent.mm',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.eg.android.AlipayGphone',
        label: '支付宝',
        subtitle: 'com.eg.android.AlipayGphone',
        bundleName: 'com.eg.android.AlipayGphone',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.tencent.mobileqq',
        label: 'QQ',
        subtitle: 'com.tencent.mobileqq',
        bundleName: 'com.tencent.mobileqq',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.alibaba.android.rimet',
        label: '钉钉',
        subtitle: 'com.alibaba.android.rimet',
        bundleName: 'com.alibaba.android.rimet',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.ss.android.lark',
        label: '飞书',
        subtitle: 'com.ss.android.lark',
        bundleName: 'com.ss.android.lark',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.taobao.taobao',
        label: '淘宝',
        subtitle: 'com.taobao.taobao',
        bundleName: 'com.taobao.taobao',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.jingdong.app.mall',
        label: '京东',
        subtitle: 'com.jingdong.app.mall',
        bundleName: 'com.jingdong.app.mall',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.sankuai.meituan',
        label: '美团',
        subtitle: 'com.sankuai.meituan',
        bundleName: 'com.sankuai.meituan',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.ss.android.ugc.aweme',
        label: '抖音',
        subtitle: 'com.ss.android.ugc.aweme',
        bundleName: 'com.ss.android.ugc.aweme',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.xingin.xhs',
        label: '小红书',
        subtitle: 'com.xingin.xhs',
        bundleName: 'com.xingin.xhs',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.autonavi.minimap',
        label: '高德地图',
        subtitle: 'com.autonavi.minimap',
        bundleName: 'com.autonavi.minimap',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.baidu.BaiduMap',
        label: '百度地图',
        subtitle: 'com.baidu.BaiduMap',
        bundleName: 'com.baidu.BaiduMap',
        abilityName: 'EntryAbility',
      },
      {
        platform: 'ohos',
        id: 'com.tencent.hm.qqmusic',
        label: 'QQ音乐',
        subtitle: 'com.tencent.hm.qqmusic',
        bundleName: 'com.tencent.hm.qqmusic',
        abilityName: 'EntryAbility',
      },
    ];
    return [...systemApps, ...commonApps];
  }

  private findPreset(id: string): LaunchableAppPayload | null {
    const apps = this.launchableApps();
    for (let i = 0; i < apps.length; i++) {
      if (apps[i].id === id || apps[i].bundleName === id) {
        return apps[i];
      }
    }
    return null;
  }

  private async openApp(call: MethodCall): Promise<void> {
    const id = ((call.argument('id') as string | null) ?? '').trim();
    const preset = this.findPreset(id);
    const bundleName =
      ((call.argument('bundleName') as string | null) ?? preset?.bundleName ?? '').trim();
    const abilityName =
      ((call.argument('abilityName') as string | null) ?? preset?.abilityName ?? '').trim();
    const action =
      ((call.argument('action') as string | null) ?? preset?.action ?? '').trim();
    const uri = ((call.argument('uri') as string | null) ?? preset?.uri ?? '').trim();
    const type = ((call.argument('type') as string | null) ?? preset?.type ?? '').trim();

    const want: Want = {};
    if (bundleName.length > 0 && abilityName.length > 0) {
      want.bundleName = bundleName;
      want.abilityName = abilityName;
    } else if (action.length > 0) {
      want.action = action;
    } else {
      throw new Error('Missing app launch target');
    }
    if (uri.length > 0) {
      want.uri = uri;
    }
    if (type.length > 0) {
      want.type = type;
    }
    await this.context.startAbility(want);
  }

  private replyWithOpen(result: MethodResult, task: Promise<void>): void {
    task
      .then(() => result.success(true))
      .catch((error: BusinessError) => {
        result.error(
          'app_launcher_error',
          error.message ?? 'Failed to open app',
          error.code ?? null
        );
      });
  }
}

class AssistantCalendarHandler {
  private context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'openCalendar':
        this.replyWithOpen(result, this.openCalendar());
        break;
      case 'fetchEvents':
        result.error(
          'unsupported',
          'HarmonyOS does not expose direct calendar reads to this app.',
          null
        );
        break;
      default:
        result.notImplemented();
    }
  }

  private async openCalendar(): Promise<void> {
    await this.context.startAbility({
      bundleName: 'com.huawei.hmos.calendar',
      abilityName: 'MainAbility'
    });
  }

  private replyWithOpen(result: MethodResult, task: Promise<void>): void {
    task
      .then(() => result.success(true))
      .catch((error: BusinessError) => {
        result.error(
          'calendar_open_error',
          error.message ?? 'Failed to open calendar',
          error.code ?? null
        );
      });
  }
}

class AssistantSmsHandler {
  onMethodCall(call: MethodCall, result: MethodResult): void {
    switch (call.method) {
      case 'fetchRecent':
        result.error(
          'unsupported',
          'HarmonyOS does not expose direct SMS inbox reads to this app.',
          null
        );
        break;
      default:
        result.notImplemented();
    }
  }
}

class AssistantLocalStoreHandler {
  private context: common.UIAbilityContext;
  private preferencesInstance: preferences.Preferences | null = null;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      switch (call.method) {
        case 'readText':
          result.success(this.readText(call));
          break;
        case 'writeText':
          this.writeText(call);
          result.success(true);
          break;
        case 'delete':
          this.delete(call);
          result.success(true);
          break;
        case 'clear':
          this.clear();
          result.success(true);
          break;
        default:
          result.notImplemented();
      }
    } catch (error) {
      const businessError = error as BusinessError;
      result.error(
        'local_store_error',
        businessError.message ?? 'Failed to access local store',
        businessError.code ?? null
      );
    }
  }

  private storeKey(call: MethodCall): string {
    const name = ((call.argument('name') as string | null) ?? '').trim();
    if (name.length === 0 || !/^[A-Za-z0-9_.-]+$/.test(name)) {
      throw new Error('Invalid local store name');
    }
    return name;
  }

  private getPreferences(): preferences.Preferences {
    if (this.preferencesInstance == null) {
      this.preferencesInstance = preferences.getPreferencesSync(
        this.context,
        { name: 'myassistant_local_store' }
      );
    }
    return this.preferencesInstance;
  }

  private readText(call: MethodCall): string {
    const prefs = this.getPreferences();
    const value = prefs.getSync(this.storeKey(call), '');
    return typeof value === 'string' ? value : '';
  }

  private writeText(call: MethodCall): void {
    const prefs = this.getPreferences();
    const content = (call.argument('content') as string | null) ?? '';
    prefs.putSync(this.storeKey(call), content);
    prefs.flushSync();
  }

  private delete(call: MethodCall): void {
    const prefs = this.getPreferences();
    prefs.deleteSync(this.storeKey(call));
    prefs.flushSync();
  }

  private clear(): void {
    const prefs = this.getPreferences();
    prefs.clearSync();
    prefs.flushSync();
  }
}

export default class EntryAbility extends FlutterAbility {
  private localStoreChannel: MethodChannel | null = null;
  private localStoreHandler: AssistantLocalStoreHandler | null = null;

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)

    const messenger = flutterEngine.getDartExecutor();
    new MethodChannel(messenger, PERMISSIONS_CHANNEL)
      .setMethodCallHandler(
        new AssistantMethodHandler(this.context, PERMISSIONS_CHANNEL)
      );
    new MethodChannel(messenger, TODO_REMINDERS_CHANNEL)
      .setMethodCallHandler(
        new AssistantMethodHandler(this.context, TODO_REMINDERS_CHANNEL)
      );
    new MethodChannel(messenger, FILE_PICKER_CHANNEL)
      .setMethodCallHandler(new AssistantFilePickerHandler(this.context));
    new MethodChannel(messenger, APP_LAUNCHER_CHANNEL)
      .setMethodCallHandler(new AssistantAppLauncherHandler(this.context));
    new MethodChannel(messenger, CALENDAR_CHANNEL)
      .setMethodCallHandler(new AssistantCalendarHandler(this.context));
    new MethodChannel(messenger, SMS_CHANNEL)
      .setMethodCallHandler(new AssistantSmsHandler());
    this.localStoreHandler = new AssistantLocalStoreHandler(this.context);
    this.localStoreChannel = new MethodChannel(messenger, LOCAL_STORE_CHANNEL);
    this.localStoreChannel.setMethodCallHandler(this.localStoreHandler);
  }
}
