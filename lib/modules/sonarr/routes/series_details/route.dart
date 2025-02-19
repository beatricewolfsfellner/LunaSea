import 'package:collection/collection.dart' show IterableExtension;
import 'package:flutter/material.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/sonarr.dart';
import 'package:lunasea/modules/sonarr/routes/series_details/sheets/links.dart';

class SonarrSeriesDetailsRouter extends SonarrPageRouter {
  SonarrSeriesDetailsRouter() : super('/sonarr/series/:seriesid');

  @override
  _SonarrSeriesDetails widget([
    int seriesId = -1,
  ]) {
    return _SonarrSeriesDetails(seriesId: seriesId);
  }

  @override
  Future<void> navigateTo(
    BuildContext context, [
    int seriesId = -1,
  ]) async {
    return LunaRouter.router.navigateTo(context, route(seriesId));
  }

  @override
  String route([int seriesId = -1]) {
    return fullRoute.replaceFirst(
      ':seriesid',
      seriesId.toString(),
    );
  }

  @override
  void defineRoute(FluroRouter router) {
    super.withParameterRouteDefinition(
      router,
      (context, params) {
        int seriesId = (params['seriesid']?.isNotEmpty ?? false)
            ? (int.tryParse(params['seriesid']![0]) ?? -1)
            : -1;
        return _SonarrSeriesDetails(seriesId: seriesId);
      },
    );
  }
}

class _SonarrSeriesDetails extends StatefulWidget {
  final int seriesId;

  const _SonarrSeriesDetails({
    Key? key,
    required this.seriesId,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<_SonarrSeriesDetails> with LunaLoadCallbackMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  SonarrSeries? series;
  PageController? _pageController;

  @override
  Future<void> loadCallback() async {
    if (widget.seriesId > 0) {
      SonarrSeries? result =
          (await context.read<SonarrState>().series)![widget.seriesId];
      setState(() => series = result);
      context.read<SonarrState>().fetchQualityProfiles();
      context.read<SonarrState>().fetchLanguageProfiles();
      context.read<SonarrState>().fetchTags();
      await context.read<SonarrState>().fetchSeries(widget.seriesId);
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(
      initialPage: SonarrDatabaseValue.NAVIGATION_INDEX_SERIES_DETAILS.data,
    );
  }

  List<SonarrTag> _findTags(
    List<int>? tagIds,
    List<SonarrTag> tags,
  ) {
    return tags.where((tag) => tagIds!.contains(tag.id)).toList();
  }

  SonarrQualityProfile? _findQualityProfile(
    int? qualityProfileId,
    List<SonarrQualityProfile> profiles,
  ) {
    return profiles.firstWhereOrNull(
      (profile) => profile.id == qualityProfileId,
    );
  }

  SonarrLanguageProfile? _findLanguageProfile(
    int? languageProfileId,
    List<SonarrLanguageProfile> profiles,
  ) {
    return profiles.firstWhereOrNull(
      (profile) => profile.id == languageProfileId,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seriesId <= 0) {
      return LunaInvalidRoute(
        title: 'sonarr.SeriesDetails'.tr(),
        message: 'sonarr.SeriesNotFound'.tr(),
      );
    }
    return LunaScaffold(
      scaffoldKey: _scaffoldKey,
      module: LunaModule.SONARR,
      appBar: _appBar() as PreferredSizeWidget?,
      bottomNavigationBar:
          context.watch<SonarrState>().enabled ? _bottomNavigationBar() : null,
      body: _body(),
    );
  }

  Widget _appBar() {
    List<Widget>? _actions;

    if (series != null) {
      _actions = [
        LunaIconButton(
          icon: LunaIcons.LINK,
          onPressed: () => LinksSheet(series: series!).show(context: context),
        ),
        LunaIconButton(
          icon: LunaIcons.EDIT,
          onPressed: () async => SonarrEditSeriesRouter().navigateTo(
            context,
            widget.seriesId,
          ),
        ),
        SonarrAppBarSeriesSettingsAction(seriesId: widget.seriesId),
      ];
    }
    return LunaAppBar(
      title: 'sonarr.SeriesDetails'.tr(),
      scrollControllers: SonarrSeriesDetailsNavigationBar.scrollControllers,
      pageController: _pageController,
      actions: _actions,
    );
  }

  Widget? _bottomNavigationBar() {
    if (series == null) return null;
    return SonarrSeriesDetailsNavigationBar(
      pageController: _pageController,
    );
  }

  Widget _body() {
    return Consumer<SonarrState>(
      builder: (context, state, _) => FutureBuilder(
        future: Future.wait([
          state.qualityProfiles!,
          state.languageProfiles!,
          state.tags!,
          state.series!,
        ]),
        builder: (context, AsyncSnapshot<List<Object>> snapshot) {
          if (snapshot.hasError) {
            if (snapshot.connectionState != ConnectionState.waiting) {
              LunaLogger().error(
                'Unable to pull Sonarr series details',
                snapshot.error,
                snapshot.stackTrace,
              );
            }
            return LunaMessage.error(onTap: loadCallback);
          }
          if (snapshot.hasData) {
            series =
                (snapshot.data![3] as Map<int, SonarrSeries>)[widget.seriesId];
            if (series == null) {
              return LunaMessage.goBack(
                text: 'sonarr.SeriesNotFound'.tr(),
                context: context,
              );
            }
            SonarrQualityProfile? quality = _findQualityProfile(
              series!.qualityProfileId,
              snapshot.data![0] as List<SonarrQualityProfile>,
            );
            SonarrLanguageProfile? language = _findLanguageProfile(
              series!.languageProfileId,
              snapshot.data![1] as List<SonarrLanguageProfile>,
            );
            List<SonarrTag> tags =
                _findTags(series!.tags, snapshot.data![2] as List<SonarrTag>);
            return _pages(
              qualityProfile: quality,
              languageProfile: language,
              tags: tags,
            );
          }
          return const LunaLoader();
        },
      ),
    );
  }

  Widget _pages({
    required SonarrQualityProfile? qualityProfile,
    required SonarrLanguageProfile? languageProfile,
    required List<SonarrTag> tags,
  }) {
    return ChangeNotifierProvider(
      create: (context) => SonarrSeriesDetailsState(
        context: context,
        series: series!,
      ),
      builder: (context, _) => LunaPageView(
        controller: _pageController,
        children: [
          SonarrSeriesDetailsOverviewPage(
            series: series!,
            qualityProfile: qualityProfile,
            languageProfile: languageProfile,
            tags: tags,
          ),
          SonarrSeriesDetailsSeasonsPage(series: series),
          const SonarrSeriesDetailsHistoryPage(),
        ],
      ),
    );
  }
}
