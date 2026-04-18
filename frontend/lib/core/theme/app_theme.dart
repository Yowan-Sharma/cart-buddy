import 'package:forui/forui.dart';
import 'app_colors.dart';

class AppTheme {
  static FThemeData get light {
    final base = FThemes.zinc.light.desktop;

    return FThemeData(
      touch: true,
      colors: base.colors.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        background: AppColors.background,
      ),
      typography: base.typography,
      style: base.style,
    );
  }

  static FThemeData get dark {
    final base = FThemes.zinc.dark.desktop;

    return FThemeData(
      touch: true,
      colors: base.colors,
      typography: base.typography,
      style: base.style,
    );
  }
}
