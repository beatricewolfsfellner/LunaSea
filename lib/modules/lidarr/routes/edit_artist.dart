import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:lunasea/core.dart';
import 'package:lunasea/modules/lidarr.dart';

class LidarrEditArtistArguments {
  final LidarrCatalogueData? entry;

  LidarrEditArtistArguments({
    required this.entry,
  });
}

class LidarrEditArtist extends StatefulWidget {
  static const ROUTE_NAME = '/lidarr/edit/artist';

  const LidarrEditArtist({
    Key? key,
  }) : super(key: key);

  @override
  State<LidarrEditArtist> createState() => _State();
}

class _State extends State<LidarrEditArtist> with LunaScrollControllerMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  LidarrEditArtistArguments? _arguments;
  Future<void>? _future;

  List<LidarrQualityProfile> _qualityProfiles = [];
  List<LidarrMetadataProfile> _metadataProfiles = [];
  LidarrQualityProfile? _qualityProfile;
  LidarrMetadataProfile? _metadataProfile;
  String? _path;
  bool? _monitored;
  bool? _albumFolders;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((_) {
      setState(() => _arguments = ModalRoute.of(context)!.settings.arguments
          as LidarrEditArtistArguments?);
      _refresh();
    });
  }

  @override
  Widget build(BuildContext context) => LunaScaffold(
        scaffoldKey: _scaffoldKey,
        body: _body,
        appBar: _appBar as PreferredSizeWidget?,
        bottomNavigationBar: _bottomActionBar(),
      );

  Future<void> _refresh() async => setState(() => {_future = _fetch()});

  Future<bool> _fetch() async {
    final _api = LidarrAPI.from(LunaProfile.current);
    return _fetchProfiles(_api).then((_) => _fetchMetadata(_api)).then((_) {
      _path = _arguments!.entry!.path;
      _monitored = _arguments!.entry!.monitored;
      _albumFolders = _arguments!.entry!.albumFolders;
      return true;
    });
  }

  Future<void> _fetchProfiles(LidarrAPI api) async {
    return await api.getQualityProfiles().then((profiles) {
      _qualityProfiles = profiles.values.toList();
      if (_qualityProfiles.isNotEmpty) {
        for (var profile in _qualityProfiles) {
          if (profile.id == _arguments!.entry!.qualityProfile) {
            _qualityProfile = profile;
          }
        }
      }
    });
  }

  Future<void> _fetchMetadata(LidarrAPI api) async {
    return await api.getMetadataProfiles().then((metadatas) {
      _metadataProfiles = metadatas.values.toList();
      if (_metadataProfiles.isNotEmpty) {
        for (var profile in _metadataProfiles) {
          if (profile.id == _arguments!.entry!.metadataProfile) {
            _metadataProfile = profile;
          }
        }
      }
    });
  }

  Widget get _appBar => LunaAppBar(
        title: _arguments?.entry?.title ?? 'Edit Artist',
        scrollControllers: [scrollController],
      );

  Widget _bottomActionBar() {
    return LunaBottomActionBar(
      actions: [
        LunaButton.text(
          text: 'lunasea.Update'.tr(),
          icon: Icons.edit_rounded,
          onTap: _save,
        ),
      ],
    );
  }

  Widget get _body => FutureBuilder(
        future: _future,
        builder: (context, snapshot) {
          switch (snapshot.connectionState) {
            case ConnectionState.done:
              {
                if (snapshot.hasError || snapshot.data == null)
                  return LunaMessage.error(onTap: _refresh);
                return _list;
              }
            case ConnectionState.none:
            case ConnectionState.waiting:
            case ConnectionState.active:
            default:
              return const LunaLoader();
          }
        },
      );

  Widget get _list => LunaListView(
        controller: scrollController,
        children: <Widget>[
          LunaBlock(
            title: 'Monitored',
            trailing: LunaSwitch(
              value: _monitored!,
              onChanged: (value) => setState(() => _monitored = value),
            ),
          ),
          LunaBlock(
            title: 'Quality Profile',
            body: [TextSpan(text: _qualityProfile!.name)],
            trailing: const LunaIconButton.arrow(),
            onTap: _changeProfile,
          ),
          LunaBlock(
            title: 'Metadata Profile',
            body: [TextSpan(text: _metadataProfile!.name)],
            trailing: const LunaIconButton.arrow(),
            onTap: _changeMetadata,
          ),
          LunaBlock(
            title: 'Artist Path',
            body: [TextSpan(text: _path)],
            trailing: const LunaIconButton.arrow(),
            onTap: _changePath,
          ),
        ],
      );

  Future<void> _changePath() async {
    Tuple2<bool, String> _values =
        await LunaDialogs().editText(context, 'Artist Path', prefill: _path!);
    if (_values.item1 && mounted) setState(() => _path = _values.item2);
  }

  Future<void> _changeProfile() async {
    List<dynamic> _values =
        await LidarrDialogs.editQualityProfile(context, _qualityProfiles);
    if (_values[0] && mounted) setState(() => _qualityProfile = _values[1]);
  }

  Future<void> _changeMetadata() async {
    List<dynamic> _values =
        await LidarrDialogs.editMetadataProfile(context, _metadataProfiles);
    if (_values[0] && mounted) setState(() => _metadataProfile = _values[1]);
  }

  Future<void> _save() async {
    final _api = LidarrAPI.from(LunaProfile.current);
    await _api
        .editArtist(
      _arguments!.entry!.artistID,
      _qualityProfile!,
      _metadataProfile!,
      _path,
      _monitored,
      _albumFolders,
    )
        .then((_) {
      _arguments!.entry!.qualityProfile = _qualityProfile!.id;
      _arguments!.entry!.quality = _qualityProfile!.name;
      _arguments!.entry!.metadataProfile = _metadataProfile!.id;
      _arguments!.entry!.metadata = _metadataProfile!.name;
      _arguments!.entry!.path = _path;
      _arguments!.entry!.monitored = _monitored;
      _arguments!.entry!.albumFolders = _albumFolders;
      Navigator.of(context).pop([true]);
    }).catchError((error, stack) {
      LunaLogger().error('Failed to update artist', error, stack);
      showLunaErrorSnackBar(
        title: 'Failed to Update',
        error: error,
      );
    });
  }
}
