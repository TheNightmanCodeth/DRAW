// Copyright (c) 2017, the Dart Reddit API Wrapper  project authors.
// Please see the AUTHORS file for details. All rights reserved.
// Use of this source code is governed by a BSD-style license that
// can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:reply/reply.dart';

import 'package:draw/src/auth.dart';
import 'package:draw/src/exceptions.dart';

/// A drop-in replacement for [Authenticator], used for recording and replaying
/// Reddit API interactions, used primarily for testing.
class TestAuthenticator extends Authenticator {
  final String _recordingPath;
  final Authenticator _recordAuth;
  final _recorder = new Recorder<List, dynamic>();
  bool get isRecording => (_recordAuth == null);
  Recording _recording;

  /// Creates a [TestAuthenticator] object which either reads a recording from
  /// [recordingPath] or records Reddit API requests and responses if
  /// [recordAuth] is provided. If [recordAuth] is provided, it must be a
  /// valid Authenticator with valid OAuth2 credentials that is capable of
  /// making requests to the Reddit API. Note: when recording Reddit API
  /// interactions, [writeRecording] must be called to write all prior records
  /// to the file at [recordingPath].
  TestAuthenticator(String recordingPath, {Authenticator recordAuth})
      : _recordingPath = recordingPath,
        _recordAuth = recordAuth,
        super(null, null) {
    if (isRecording) {
      final rawRecording = new File(recordingPath).readAsStringSync();
      _recording = new Recording.fromJson(JSON.decode(rawRecording),
          toRequest: (q) => q,
          toResponse: (r) => r,
          requestEquality: const ListEquality());
    }
  }

  @override
  Future refresh() async {
    if (isRecording) {
      throw new DRAWAuthenticationError('cannot refresh a TestAuthenticator.');
    }
    return _recordAuth.refresh();
  }

  @override
  Future revoke() async {
    if (isRecording) {
      throw new DRAWAuthenticationError('cannot revoke a TestAuthenticator.');
    }
    return _recordAuth.revoke();
  }

  @override
  Future<Map> get(Uri path) async {
    Map result;
    if (isRecording) {
      // TODO(bkonyi): grab the response based on query.
      return _recording.reply([path.toString()]);
    } else {
      print(path.toString());
      result = await _recordAuth.get(path);
      // TODO(bkonyi): do we always want to reply?
      _recorder.given([path.toString()]).reply(result).always();
    }
    return result;
  }

  @override
  Future<Map> post(Uri path, Map<String, String> body) async {
    Map result;
    if (isRecording) {
      return _recording.reply([path.toString(), body]);
    } else {
      print(path.toString());
      result = await _recordAuth.post(path, body);
      _recorder.given([path.toString(), body]).reply(result).always();
    }
    return result;
  }

  @override
  bool get isValid {
    return _recordAuth?.isValid ?? true;
  }

  /// Writes the recorded Reddit API requests and their corresponding responses
  /// to [recordingPath] and returns a [Future<File>], which is the file that
  /// has been written to, when in recording mode. When not in recording mode,
  /// does nothing and returns null.
  Future<File> writeRecording() {
    if (!isRecording) {
      return (new File(_recordingPath)).writeAsString(JSON
          .encode(_recorder.toRecording().toJsonEncodable(
              encodeRequest: (q) => q, encodeResponse: (r) => r))
          .toString());
    }
    return null;
  }
}