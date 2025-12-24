#!/bin/bash
mkdir -p src/android/src/com/godot/game/
[ -f src/android/src/org/godotengine/chessgame/GodotApp.java ] && mv src/android/src/org/godotengine/chessgame/GodotApp.java src/android/src/com/godot/game/GodotApp.java
rm -rf src/android/src/org
sed -i 's/package org.godotengine.chessgame;/package com.godot.game;/g' src/android/src/com/godot/game/GodotApp.java
sed -i 's/import org.godotengine.chessgame.BuildConfig;/import com.godot.game.BuildConfig;/g' src/android/src/com/godot/game/GodotApp.java
sed -i "s/namespace = 'org.godotengine.chessgame'/namespace = 'com.godot.game'/g" src/android/build.gradle
sed -i 's/appId = "org.godotengine.chessgame"/appId = "com.godot.game"/g' src/android/config.gradle
sed -i 's/android:extractNativeLibs="true"//g' src/android/AndroidManifest.xml
cp src/android/plugins/StockfishEngine/build/outputs/aar/StockfishEngine-release.aar src/android/plugins/StockfishEngine/release/StockfishEngine-release.aar
rm -f bin/android/*.apk
rm -rf plugins_backup_safety
cp -r src/android/plugins plugins_backup_safety
