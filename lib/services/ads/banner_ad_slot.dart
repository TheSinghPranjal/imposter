import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../app/theme/app_colors.dart';
import '../../core/constants/ad_config.dart';
import '../../core/constants/game_constants.dart';

/// Anchored banner for the menu and the between-rounds screen.
///
/// Keeps a reserved height so those screens do not jump once the ad loads.
/// Debug and profile builds use Google's sample units. Release builds use the
/// production unit from [AdConfig]. Nothing is requested until UMP consent
/// sets [AdConfig.canRequestAds].
class BannerAdSlot extends StatefulWidget {
  const BannerAdSlot({super.key});

  @override
  State<BannerAdSlot> createState() => _BannerAdSlotState();
}

class _BannerAdSlotState extends State<BannerAdSlot> {
  BannerAd? _banner;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_banner == null && AdConfig.adsSupported && AdConfig.canRequestAds) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!AdConfig.adsSupported || !AdConfig.canRequestAds) return;

    final width = MediaQuery.sizeOf(context).width.truncate();
    AdSize size = AdSize.banner;
    try {
      final adaptive =
          await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
      if (adaptive != null) size = adaptive;
    } catch (error) {
      debugPrint('Adaptive banner size failed: $error');
    }
    if (!mounted) return;

    final banner = BannerAd(
      adUnitId: AdConfig.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Banner failed to load: $error');
          ad.dispose();
          if (_banner == ad) _banner = null;
          if (mounted) setState(() => _loaded = false);
        },
      ),
    );

    _banner = banner;
    await banner.load();
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AdConfig.adsSupported || !AdConfig.canRequestAds) {
      return const SizedBox.shrink();
    }

    final height = _loaded && _banner != null
        ? _banner!.size.height.toDouble()
        : GameConstants.bannerAdHeight;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: _loaded && _banner != null
            ? AdWidget(ad: _banner!)
            : const ColoredBox(
                color: AppColors.deepNavy,
                child: Center(
                  child: Text(
                    'Loading ad…',
                    style: TextStyle(
                      color: AppColors.offWhite,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}
