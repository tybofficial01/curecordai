import 'package:flutter/material.dart';
import 'package:curecordai/core/theme/app_fonts.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/constants/app_text_styles.dart';
import '../../services/storage_service.dart';

class CarouselScreen extends StatefulWidget {
  const CarouselScreen({super.key});

  @override
  State<CarouselScreen> createState() => _CarouselScreenState();
}

class _CarouselScreenState extends State<CarouselScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markSeenAndNavigate(String route) async {
    await StorageService().setHasSeenCarousel(true);
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, route);
  }

  void _onNext() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _markSeenAndNavigate('/create-account');
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.topRight,
              child: TextButton(
                onPressed: () => _markSeenAndNavigate('/create-account'),
                child: Text(
                  'Skip',
                  style: AppFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primaryTeal,
                  ),
                ),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: AppStrings.carouselSlides.length,
                onPageChanged: (index) => setState(() => _currentPage = index),
                itemBuilder: (context, index) {
                  final slide = AppStrings.carouselSlides[index];
                  return _CarouselSlide(
                    imagePath: slide['image']!,
                    title: slide['title']!,
                    subtitle: slide['subtitle']!,
                    imageHeight: screenHeight * 0.55,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _DotIndicators(currentPage: _currentPage, count: 3),
                  SizedBox(
                    width: 140,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryTeal,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == 2
                            ? AppStrings.getStarted
                            : AppStrings.next,
                        style: AppTextStyles.buttonText.copyWith(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CarouselSlide extends StatelessWidget {
  const _CarouselSlide({
    required this.imagePath,
    required this.title,
    required this.subtitle,
    required this.imageHeight,
  });

  final String imagePath;
  final String title;
  final String subtitle;
  final double imageHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: imageHeight,
          color: AppColors.background,
          child: Image.asset(imagePath, fit: BoxFit.contain),
        ),
        const SizedBox(height: 24),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.darkText,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitle,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DotIndicators extends StatelessWidget {
  const _DotIndicators({required this.currentPage, required this.count});

  final int currentPage;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color:
                isActive ? AppColors.primaryTeal : AppColors.progressInactive,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
