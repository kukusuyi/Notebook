import 'theme_catalog.dart';

/// 各端共用预设来自 design-system/questrace/themes.json（生成于 theme_catalog.dart）。
/// 手机端在此基础上扩展更多配色，并提供用调色盘自选的“自定义”外观。
const customThemeKey = 'custom';

const Map<String, Map<String, dynamic>> extraThemePresets = {
  'forest': {
    'label': '松林绿',
    'seed': '#2F6F4F',
    'light': {
      'background': '#F2F6F3',
      'surface': '#FFFFFF',
      'text': '#1D2B23',
      'muted': '#556A5D',
      'border': '#D8E3DB',
    },
    'dark': {
      'background': '#0F1A14',
      'surface': '#18261D',
      'text': '#E8F1EA',
      'muted': '#A9BFB0',
      'border': '#33473A',
    },
  },
  'rose': {
    'label': '樱雾粉',
    'seed': '#C2607F',
    'light': {
      'background': '#FAF4F6',
      'surface': '#FFFFFF',
      'text': '#33222A',
      'muted': '#6E5964',
      'border': '#EBDCE2',
    },
    'dark': {
      'background': '#201519',
      'surface': '#2C1E23',
      'text': '#F7ECF0',
      'muted': '#C6ADB6',
      'border': '#4C363D',
    },
  },
  'amber': {
    'label': '落日橙',
    'seed': '#C1783C',
    'light': {
      'background': '#FAF5EF',
      'surface': '#FFFFFF',
      'text': '#2E2419',
      'muted': '#6B5A45',
      'border': '#ECDFCE',
    },
    'dark': {
      'background': '#1D1710',
      'surface': '#292018',
      'text': '#F5EDE2',
      'muted': '#C3B29B',
      'border': '#463827',
    },
  },
  'indigo': {
    'label': '星夜靛',
    'seed': '#4C55C4',
    'light': {
      'background': '#F4F4FB',
      'surface': '#FFFFFF',
      'text': '#22233A',
      'muted': '#5A5C7C',
      'border': '#DFDFF0',
    },
    'dark': {
      'background': '#131322',
      'surface': '#1D1D30',
      'text': '#ECECF8',
      'muted': '#AEB0CD',
      'border': '#383A58',
    },
  },
  'graphite': {
    'label': '石墨灰',
    'seed': '#55606C',
    'light': {
      'background': '#F4F5F7',
      'surface': '#FFFFFF',
      'text': '#21262B',
      'muted': '#5B646E',
      'border': '#DDE1E5',
    },
    'dark': {
      'background': '#14171A',
      'surface': '#1E2226',
      'text': '#EDEFF2',
      'muted': '#ADB5BD',
      'border': '#363B41',
    },
  },
  // 自定义外观：浅深色由用户选中的颜色实时推导，这里只作为缺少种子时的回退。
  customThemeKey: {
    'label': '自定义',
    'seed': '#548DAF',
    'light': {
      'background': '#F4F5F7',
      'surface': '#FFFFFF',
      'text': '#21262B',
      'muted': '#5B646E',
      'border': '#DDE1E5',
    },
    'dark': {
      'background': '#14171A',
      'surface': '#1E2226',
      'text': '#EDEFF2',
      'muted': '#ADB5BD',
      'border': '#363B41',
    },
  },
};

final Map<String, dynamic> flutterThemeCatalog = {
  ...themeCatalog,
  ...extraThemePresets,
};
