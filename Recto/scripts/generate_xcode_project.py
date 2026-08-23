#!/usr/bin/env python3
"""Generate Recto.xcodeproj/project.pbxproj and a 1024px app icon."""
from __future__ import annotations

import os
import struct
import zlib
from pathlib import Path

ROOT = Path("/agent/Recto")
SWIFT_FILES = [
    "AppStore.swift",
    "AllNotesView.swift",
    "Components.swift",
    "FolderNotesView.swift",
    "NoteEditorView.swift",
    "NotePDFRenderer.swift",
    "PdfExportView.swift",
    "ProPaywallView.swift",
    "RectoApp.swift",
    "RootView.swift",
    "TaskCenterView.swift",
    "Theme.swift",
]


def hid(n: int) -> str:
    return f"A{n:023X}"


def chunk(tag: bytes, data: bytes) -> bytes:
    return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)


def write_png(path: Path, width: int, height: int, rgba: bytes) -> None:
    raw = b""
    stride = width * 4
    for y in range(height):
        raw += b"\x00" + rgba[y * stride : (y + 1) * stride]
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    path.write_bytes(png)


def make_icon(path: Path, size: int = 1024) -> None:
    px = bytearray(size * size * 4)
    bg = (10, 10, 12, 255)
    blue = (74, 134, 232, 255)
    fill = (98, 168, 245, 255)
    white = (255, 255, 255, 255)

    def setp(x, y, c):
        if 0 <= x < size and 0 <= y < size:
            i = (y * size + x) * 4
            px[i : i + 4] = bytes(c)

    for y in range(size):
        for x in range(size):
            setp(x, y, bg)

    # Rounded checkbox
    left, top, box = 280, 280, 464
    radius = 72
    stroke = 28

    def inside_round_rect(x, y, l, t, w, h, r):
        cx = min(max(x, l + r), l + w - r)
        cy = min(max(y, t + r), t + h - r)
        if abs(x - cx) <= r and abs(y - cy) <= r:
            return (x - cx) ** 2 + (y - cy) ** 2 <= r * r
        return l <= x <= l + w and t <= y <= t + h

    for y in range(top, top + box):
        for x in range(left, left + box):
            outer = inside_round_rect(x, y, left, top, box, box, radius)
            inner = inside_round_rect(
                x, y, left + stroke, top + stroke, box - 2 * stroke, box - 2 * stroke, max(8, radius - stroke)
            )
            if outer and not inner:
                setp(x, y, blue)
            elif inner:
                setp(x, y, fill)

    # Check mark
    for t in range(0, 1000):
        # left stroke
        x = int(left + 110 + t * 0.16)
        y = int(top + 240 + t * 0.18)
        if t < 280:
            for d in range(-18, 19):
                setp(x + d, y + d // 3, white)
        # right stroke
        x2 = int(left + 155 + t * 0.28)
        y2 = int(top + 290 - t * 0.22)
        if t < 420:
            for d in range(-18, 19):
                setp(x2 + d, y2 - d // 4, white)

    write_png(path, size, size, bytes(px))


def pbxproj() -> str:
    file_refs = {}
    build_files = {}
    n = 1
    for name in SWIFT_FILES:
        file_refs[name] = hid(n)
        n += 1
        build_files[name] = hid(n)
        n += 1

    assets_ref = hid(n)
    n += 1
    assets_build = hid(n)
    n += 1
    sources_phase = hid(n)
    n += 1
    resources_phase = hid(n)
    n += 1
    frameworks_phase = hid(n)
    n += 1
    target = hid(n)
    n += 1
    project = hid(n)
    n += 1
    main_group = hid(n)
    n += 1
    products = hid(n)
    n += 1
    src_group = hid(n)
    n += 1
    product_ref = hid(n)
    n += 1
    cfg_list_proj = hid(n)
    n += 1
    cfg_list_target = hid(n)
    n += 1
    debug_proj = hid(n)
    n += 1
    release_proj = hid(n)
    n += 1
    debug_target = hid(n)
    n += 1
    release_target = hid(n)

    build_file_entries = "\n".join(
        f"\t\t{build_files[name]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {file_refs[name]} /* {name} */; }};"
        for name in SWIFT_FILES
    )
    build_file_entries += (
        f"\n\t\t{assets_build} /* Assets.xcassets in Resources */ = "
        f"{{isa = PBXBuildFile; fileRef = {assets_ref} /* Assets.xcassets */; }};"
    )

    file_ref_entries = "\n".join(
        f"\t\t{file_refs[name]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};"
        for name in SWIFT_FILES
    )
    file_ref_entries += (
        f"\n\t\t{assets_ref} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};"
        f"\n\t\t{product_ref} /* Recto.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = Recto.app; sourceTree = BUILT_PRODUCTS_DIR; }};"
    )

    src_children = "\n".join(f"\t\t\t\t{file_refs[name]} /* {name} */," for name in SWIFT_FILES)
    src_children += f"\n\t\t\t\t{assets_ref} /* Assets.xcassets */,"

    sources_files = "\n".join(f"\t\t\t\t{build_files[name]} /* {name} in Sources */," for name in SWIFT_FILES)

    common_target = """
				ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon;
				ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME = AccentColor;
				CODE_SIGN_STYLE = Automatic;
				CURRENT_PROJECT_VERSION = 1;
				DEVELOPMENT_TEAM = "";
				ENABLE_PREVIEWS = YES;
				GENERATE_INFOPLIST_FILE = YES;
				INFOPLIST_KEY_CFBundleDisplayName = Recto;
				INFOPLIST_KEY_LSApplicationCategoryType = public.app-category.productivity;
				INFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;
				INFOPLIST_KEY_UILaunchScreen_Generation = YES;
				INFOPLIST_KEY_UISupportedInterfaceOrientations = UIInterfaceOrientationPortrait;
				INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = "UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight";
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				LD_RUNPATH_SEARCH_PATHS = (
					"$(inherited)",
					"@executable_path/Frameworks",
				);
				MARKETING_VERSION = 1.0;
				PRODUCT_BUNDLE_IDENTIFIER = com.recto.app;
				PRODUCT_NAME = "$(TARGET_NAME)";
				SUPPORTED_PLATFORMS = "iphoneos iphonesimulator";
				SUPPORTS_MACCATALYST = NO;
				SWIFT_EMIT_LOC_STRINGS = YES;
				SWIFT_VERSION = 5.0;
				TARGETED_DEVICE_FAMILY = "1,2";
"""

    proj_debug = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = dwarf;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				ENABLE_TESTABILITY = YES;
				GCC_DYNAMIC_NO_PIC = NO;
				GCC_OPTIMIZATION_LEVEL = 0;
				GCC_PREPROCESSOR_DEFINITIONS = (
					"DEBUG=1",
					"$(inherited)",
				);
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = INCLUDE_SOURCE;
				ONLY_ACTIVE_ARCH = YES;
				SDKROOT = iphoneos;
				SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";
				SWIFT_OPTIMIZATION_LEVEL = "-Onone";
"""

    proj_release = """
				ALWAYS_SEARCH_USER_PATHS = NO;
				ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS = YES;
				CLANG_ANALYZER_NONNULL = YES;
				CLANG_ENABLE_MODULES = YES;
				CLANG_ENABLE_OBJC_ARC = YES;
				COPY_PHASE_STRIP = NO;
				DEBUG_INFORMATION_FORMAT = "dwarf-with-dsym";
				ENABLE_NS_ASSERTIONS = NO;
				ENABLE_STRICT_OBJC_MSGSEND = YES;
				GCC_OPTIMIZATION_LEVEL = s;
				IPHONEOS_DEPLOYMENT_TARGET = 17.0;
				MTL_ENABLE_DEBUG_INFO = NO;
				SDKROOT = iphoneos;
				SWIFT_COMPILATION_MODE = wholemodule;
				VALIDATE_PRODUCT = YES;
"""

    return f"""// !$*UTF8*$!
{{
	archiveVersion = 1;
	classes = {{
	}};
	objectVersion = 56;
	objects = {{

/* Begin PBXBuildFile section */
{build_file_entries}
/* End PBXBuildFile section */

/* Begin PBXFileReference section */
{file_ref_entries}
/* End PBXFileReference section */

/* Begin PBXFrameworksBuildPhase section */
		{frameworks_phase} /* Frameworks */ = {{
			isa = PBXFrameworksBuildPhase;
			buildActionMask = 2147483647;
			files = (
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXFrameworksBuildPhase section */

/* Begin PBXGroup section */
		{main_group} = {{
			isa = PBXGroup;
			children = (
				{src_group} /* Recto */,
				{products} /* Products */,
			);
			sourceTree = "<group>";
		}};
		{products} /* Products */ = {{
			isa = PBXGroup;
			children = (
				{product_ref} /* Recto.app */,
			);
			name = Products;
			sourceTree = "<group>";
		}};
		{src_group} /* Recto */ = {{
			isa = PBXGroup;
			children = (
{src_children}
			);
			path = Recto;
			sourceTree = "<group>";
		}};
/* End PBXGroup section */

/* Begin PBXNativeTarget section */
		{target} /* Recto */ = {{
			isa = PBXNativeTarget;
			buildConfigurationList = {cfg_list_target} /* Build configuration list for PBXNativeTarget "Recto" */;
			buildPhases = (
				{sources_phase} /* Sources */,
				{frameworks_phase} /* Frameworks */,
				{resources_phase} /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = Recto;
			productName = Recto;
			productReference = {product_ref} /* Recto.app */;
			productType = "com.apple.product-type.application";
		}};
/* End PBXNativeTarget section */

/* Begin PBXProject section */
		{project} /* Project object */ = {{
			isa = PBXProject;
			attributes = {{
				BuildIndependentTargetsInParallel = 1;
				LastSwiftUpdateCheck = 1500;
				LastUpgradeCheck = 1500;
				ORGANIZATIONNAME = Recto;
				TargetAttributes = {{
					{target} = {{
						CreatedOnToolsVersion = 15.0;
					}};
				}};
			}};
			buildConfigurationList = {cfg_list_proj} /* Build configuration list for PBXProject "Recto" */;
			compatibilityVersion = "Xcode 14.0";
			developmentRegion = en;
			hasScannedForEncodings = 0;
			knownRegions = (
				en,
				Base,
			);
			mainGroup = {main_group};
			productRefGroup = {products} /* Products */;
			projectDirPath = "";
			projectRoot = "";
			targets = (
				{target} /* Recto */,
			);
		}};
/* End PBXProject section */

/* Begin PBXResourcesBuildPhase section */
		{resources_phase} /* Resources */ = {{
			isa = PBXResourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
				{assets_build} /* Assets.xcassets in Resources */,
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXResourcesBuildPhase section */

/* Begin PBXSourcesBuildPhase section */
		{sources_phase} /* Sources */ = {{
			isa = PBXSourcesBuildPhase;
			buildActionMask = 2147483647;
			files = (
{sources_files}
			);
			runOnlyForDeploymentPostprocessing = 0;
		}};
/* End PBXSourcesBuildPhase section */

/* Begin XCBuildConfiguration section */
		{debug_proj} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{proj_debug}
			}};
			name = Debug;
		}};
		{release_proj} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{proj_release}
			}};
			name = Release;
		}};
		{debug_target} /* Debug */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{common_target}
			}};
			name = Debug;
		}};
		{release_target} /* Release */ = {{
			isa = XCBuildConfiguration;
			buildSettings = {{{common_target}
			}};
			name = Release;
		}};
/* End XCBuildConfiguration section */

/* Begin XCConfigurationList section */
		{cfg_list_proj} /* Build configuration list for PBXProject "Recto" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_proj} /* Debug */,
				{release_proj} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
		{cfg_list_target} /* Build configuration list for PBXNativeTarget "Recto" */ = {{
			isa = XCConfigurationList;
			buildConfigurations = (
				{debug_target} /* Debug */,
				{release_target} /* Release */,
			);
			defaultConfigurationIsVisible = 0;
			defaultConfigurationName = Release;
		}};
/* End XCConfigurationList section */
	}};
	rootObject = {project} /* Project object */;
}}
"""


SCHEME = """<?xml version="1.0" encoding="UTF-8"?>
<Scheme
   LastUpgradeVersion = "1500"
   version = "1.7">
   <BuildAction
      parallelizeBuildables = "YES"
      buildImplicitDependencies = "YES">
      <BuildActionEntries>
         <BuildActionEntry
            buildForTesting = "YES"
            buildForRunning = "YES"
            buildForProfiling = "YES"
            buildForArchiving = "YES"
            buildForAnalyzing = "YES">
            <BuildableReference
               BuildableIdentifier = "primary"
               BlueprintIdentifier = "TARGET"
               BuildableName = "Recto.app"
               BlueprintName = "Recto"
               ReferencedContainer = "container:Recto.xcodeproj">
            </BuildableReference>
         </BuildActionEntry>
      </BuildActionEntries>
   </BuildAction>
   <TestAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      shouldUseLaunchSchemeArgsEnv = "YES"
      shouldAutocreateTestPlan = "YES">
   </TestAction>
   <LaunchAction
      buildConfiguration = "Debug"
      selectedDebuggerIdentifier = "Xcode.DebuggerFoundation.Debugger.LLDB"
      selectedLauncherIdentifier = "Xcode.DebuggerFoundation.Launcher.LLDB"
      launchStyle = "0"
      useCustomWorkingDirectory = "NO"
      ignoresPersistentStateOnLaunch = "NO"
      debugDocumentVersioning = "YES"
      debugServiceExtension = "internal"
      allowLocationSimulation = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "TARGET"
            BuildableName = "Recto.app"
            BlueprintName = "Recto"
            ReferencedContainer = "container:Recto.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </LaunchAction>
   <ProfileAction
      buildConfiguration = "Release"
      shouldUseLaunchSchemeArgsEnv = "YES"
      savedToolIdentifier = ""
      useCustomWorkingDirectory = "NO"
      debugDocumentVersioning = "YES">
      <BuildableProductRunnable
         runnableDebuggingMode = "0">
         <BuildableReference
            BuildableIdentifier = "primary"
            BlueprintIdentifier = "TARGET"
            BuildableName = "Recto.app"
            BlueprintName = "Recto"
            ReferencedContainer = "container:Recto.xcodeproj">
         </BuildableReference>
      </BuildableProductRunnable>
   </ProfileAction>
   <AnalyzeAction
      buildConfiguration = "Debug">
   </AnalyzeAction>
   <ArchiveAction
      buildConfiguration = "Release"
      revealArchiveInOrganizer = "YES">
   </ArchiveAction>
</Scheme>
"""


def main() -> None:
    # Recompute target id the same way pbxproj() does — parse from generated file instead.
    text = pbxproj()
    # Extract native target id
    import re

    match = re.search(r"([A-F0-9]{24}) /\* Recto \*/ = \{\n\t\t\tisa = PBXNativeTarget;", text)
    target_id = match.group(1) if match else "A00000000000000000000001"
    scheme = SCHEME.replace("TARGET", target_id)

    proj_dir = ROOT / "Recto.xcodeproj"
    proj_dir.mkdir(parents=True, exist_ok=True)
    (proj_dir / "project.pbxproj").write_text(text)
    scheme_dir = proj_dir / "xcshareddata" / "xcschemes"
    scheme_dir.mkdir(parents=True, exist_ok=True)
    (scheme_dir / "Recto.xcscheme").write_text(scheme)

    assets = ROOT / "Recto" / "Assets.xcassets"
    (assets / "Contents.json").write_text(
        """{
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
    )
    accent = assets / "AccentColor.colorset"
    accent.mkdir(parents=True, exist_ok=True)
    (accent / "Contents.json").write_text(
        """{
  "colors" : [
    {
      "color" : {
        "color-space" : "srgb",
        "components" : { "alpha" : "1.000", "blue" : "0.910", "green" : "0.525", "red" : "0.290" }
      },
      "idiom" : "universal"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
    )
    iconset = assets / "AppIcon.appiconset"
    iconset.mkdir(parents=True, exist_ok=True)
    (iconset / "Contents.json").write_text(
        """{
  "images" : [
    {
      "filename" : "AppIcon.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : { "author" : "xcode", "version" : 1 }
}
"""
    )
    print("Writing app icon…")
    make_icon(iconset / "AppIcon.png")
    print("Wrote project and assets.")


if __name__ == "__main__":
    main()
