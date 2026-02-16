#!/usr/bin/env python3
"""
Generates WorkoutMD.xcodeproj/project.pbxproj for a SwiftUI iOS 17+ app.
Run from the WorkoutMD/ directory:
    python3 generate_xcodeproj.py
"""

import os

# ---------------------------------------------------------------------------
# UUID map (24-char hex, Xcode style)
# ---------------------------------------------------------------------------
U = {
    "PROJECT":              "11111111111111111111110A",
    "MAIN_GROUP":           "11111111111111111111110B",
    "PRODUCTS_GROUP":       "11111111111111111111110C",
    "APP_TARGET":           "11111111111111111111110D",
    "APP_PRODUCT":          "11111111111111111111110E",  # WorkoutMD.app
    "SOURCES_PHASE":        "11111111111111111111110F",
    "RESOURCES_PHASE":      "111111111111111111111110",
    "FRAMEWORKS_PHASE":     "111111111111111111111111",
    "PROJ_CFG_LIST":        "111111111111111111111112",
    "TGT_CFG_LIST":         "111111111111111111111113",
    "DEBUG_CFG_PROJ":       "111111111111111111111114",
    "RELEASE_CFG_PROJ":     "111111111111111111111115",
    "DEBUG_CFG_TGT":        "111111111111111111111116",
    "RELEASE_CFG_TGT":      "111111111111111111111117",
    "WORKOUTMD_SRC_GROUP":  "111111111111111111111118",
    "MODELS_GROUP":         "111111111111111111111119",
    "VIEWS_GROUP":          "11111111111111111111111A",
    "SERVICES_GROUP":       "11111111111111111111111B",
    "SETTINGS_GROUP":       "11111111111111111111111C",
    # FileReference UUIDs
    "FR_APP":               "22222222222222222222220A",  # WorkoutMDApp.swift
    "FR_CONTENT":           "22222222222222222222220B",
    "FR_TEMPLATE":          "22222222222222222222220C",  # Models/WorkoutTemplate.swift
    "FR_EXERCISE":          "22222222222222222222220D",
    "FR_SET":               "22222222222222222222220E",
    "FR_VAULTSETUP":        "22222222222222222222220F",
    "FR_TEMPLATEPICKER":    "222222222222222222222210",
    "FR_SESSION":           "222222222222222222222211",
    "FR_EXERCISECARD":      "222222222222222222222212",
    "FR_SETROW":            "222222222222222222222213",
    "FR_VIDEO":             "222222222222222222222214",
    "FR_VAULTSERVICE":      "222222222222222222222215",
    "FR_PARSER":            "222222222222222222222216",
    "FR_WRITER":            "222222222222222222222217",
    "FR_SETTINGS":          "222222222222222222222218",
    "FR_ASSETS":            "222222222222222222222219",
    "FR_INFOPLIST":         "22222222222222222222221A",
    "FR_HIKE":              "22222222222222222222221B",
    # BuildFile UUIDs (one per source file)
    "BF_APP":               "33333333333333333333330A",
    "BF_CONTENT":           "33333333333333333333330B",
    "BF_TEMPLATE":          "33333333333333333333330C",
    "BF_EXERCISE":          "33333333333333333333330D",
    "BF_SET":               "33333333333333333333330E",
    "BF_VAULTSETUP":        "33333333333333333333330F",
    "BF_TEMPLATEPICKER":    "333333333333333333333310",
    "BF_SESSION":           "333333333333333333333311",
    "BF_EXERCISECARD":      "333333333333333333333312",
    "BF_SETROW":            "333333333333333333333313",
    "BF_VIDEO":             "333333333333333333333314",
    "BF_VAULTSERVICE":      "333333333333333333333315",
    "BF_PARSER":            "333333333333333333333316",
    "BF_WRITER":            "333333333333333333333317",
    "BF_SETTINGS":          "333333333333333333333318",
    "BF_ASSETS":            "333333333333333333333319",
    "BF_HIKE":              "33333333333333333333331A",
}

# ---------------------------------------------------------------------------
# File definitions
# ---------------------------------------------------------------------------
SWIFT_FILES = [
    # (buildfile_key, fileref_key, path_in_project, display_name)
    ("BF_APP",           "FR_APP",           "WorkoutMD/WorkoutMDApp.swift",            "WorkoutMDApp.swift"),
    ("BF_CONTENT",       "FR_CONTENT",       "WorkoutMD/ContentView.swift",             "ContentView.swift"),
    ("BF_TEMPLATE",      "FR_TEMPLATE",      "WorkoutMD/Models/WorkoutTemplate.swift",  "WorkoutTemplate.swift"),
    ("BF_EXERCISE",      "FR_EXERCISE",      "WorkoutMD/Models/Exercise.swift",         "Exercise.swift"),
    ("BF_SET",           "FR_SET",           "WorkoutMD/Models/WorkoutSet.swift",       "WorkoutSet.swift"),
    ("BF_VAULTSETUP",    "FR_VAULTSETUP",    "WorkoutMD/Views/VaultSetupView.swift",    "VaultSetupView.swift"),
    ("BF_TEMPLATEPICKER","FR_TEMPLATEPICKER","WorkoutMD/Views/TemplatePickerView.swift","TemplatePickerView.swift"),
    ("BF_SESSION",       "FR_SESSION",       "WorkoutMD/Views/WorkoutSessionView.swift","WorkoutSessionView.swift"),
    ("BF_EXERCISECARD",  "FR_EXERCISECARD",  "WorkoutMD/Views/ExerciseCardView.swift",  "ExerciseCardView.swift"),
    ("BF_SETROW",        "FR_SETROW",        "WorkoutMD/Views/SetRowView.swift",        "SetRowView.swift"),
    ("BF_VIDEO",         "FR_VIDEO",         "WorkoutMD/Views/VideoPlayerView.swift",   "VideoPlayerView.swift"),
    ("BF_VAULTSERVICE",  "FR_VAULTSERVICE",  "WorkoutMD/Services/VaultService.swift",   "VaultService.swift"),
    ("BF_PARSER",        "FR_PARSER",        "WorkoutMD/Services/MarkdownParser.swift", "MarkdownParser.swift"),
    ("BF_WRITER",        "FR_WRITER",        "WorkoutMD/Services/MarkdownWriter.swift", "MarkdownWriter.swift"),
    ("BF_SETTINGS",      "FR_SETTINGS",      "WorkoutMD/Settings/SettingsView.swift",   "SettingsView.swift"),
    ("BF_HIKE",          "FR_HIKE",          "WorkoutMD/Views/HikeSessionView.swift",   "HikeSessionView.swift"),
]

def pbxproj():
    lines = []
    a = lines.append

    a("// !$*UTF8*$!")
    a("{")
    a("\tarchiveVersion = 1;")
    a("\tclasses = {")
    a("\t};")
    a("\tobjectVersion = 56;")
    a("\tobjects = {")
    a("")

    # ---- PBXBuildFile section ----
    a("/* Begin PBXBuildFile section */")
    for bf_key, fr_key, path, name in SWIFT_FILES:
        a(f"\t\t{U[bf_key]} /* {name} in Sources */ = {{isa = PBXBuildFile; fileRef = {U[fr_key]} /* {name} */; }};")
    # Assets resource
    a(f"\t\t{U['BF_ASSETS']} /* Assets.xcassets in Resources */ = {{isa = PBXBuildFile; fileRef = {U['FR_ASSETS']} /* Assets.xcassets */; }};")
    a("/* End PBXBuildFile section */")
    a("")

    # ---- PBXFileReference section ----
    a("/* Begin PBXFileReference section */")
    # .app product — uses APP_PRODUCT uuid, not FR_APP
    a(f"\t\t{U['APP_PRODUCT']} /* WorkoutMD.app */ = {{isa = PBXFileReference; explicitFileType = wrapper.application; includeInIndex = 0; path = WorkoutMD.app; sourceTree = BUILT_PRODUCTS_DIR; }};")
    for bf_key, fr_key, path, name in SWIFT_FILES:
        # path is relative to its parent group, which is already set via group `path` key.
        # So just use the filename here.
        a(f"\t\t{U[fr_key]} /* {name} */ = {{isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = {name}; sourceTree = \"<group>\"; }};")
    # Assets
    a(f"\t\t{U['FR_ASSETS']} /* Assets.xcassets */ = {{isa = PBXFileReference; lastKnownFileType = folder.assetcatalog; path = Assets.xcassets; sourceTree = \"<group>\"; }};")
    a("/* End PBXFileReference section */")
    a("")

    # ---- PBXFrameworksBuildPhase ----
    a("/* Begin PBXFrameworksBuildPhase section */")
    a(f"\t\t{U['FRAMEWORKS_PHASE']} /* Frameworks */ = {{")
    a("\t\t\tisa = PBXFrameworksBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXFrameworksBuildPhase section */")
    a("")

    # ---- PBXGroup section ----
    a("/* Begin PBXGroup section */")

    # Main group
    a(f"\t\t{U['MAIN_GROUP']} = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    a(f"\t\t\t\t{U['WORKOUTMD_SRC_GROUP']} /* WorkoutMD */,")
    a(f"\t\t\t\t{U['PRODUCTS_GROUP']} /* Products */,")
    a("\t\t\t);")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    # Products group
    a(f"\t\t{U['PRODUCTS_GROUP']} /* Products */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    a(f"\t\t\t\t{U['APP_PRODUCT']} /* WorkoutMD.app */,")
    a("\t\t\t);")
    a("\t\t\tname = Products;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    # WorkoutMD source group (top-level files + subgroups)
    top_level = [f for f in SWIFT_FILES if f[2].count("/") == 1]  # WorkoutMD/Foo.swift
    a(f"\t\t{U['WORKOUTMD_SRC_GROUP']} /* WorkoutMD */ = {{")
    a("\t\t\tisa = PBXGroup;")
    a("\t\t\tchildren = (")
    for bf_key, fr_key, path, name in top_level:
        a(f"\t\t\t\t{U[fr_key]} /* {name} */,")
    a(f"\t\t\t\t{U['MODELS_GROUP']} /* Models */,")
    a(f"\t\t\t\t{U['VIEWS_GROUP']} /* Views */,")
    a(f"\t\t\t\t{U['SERVICES_GROUP']} /* Services */,")
    a(f"\t\t\t\t{U['SETTINGS_GROUP']} /* Settings */,")
    a(f"\t\t\t\t{U['FR_ASSETS']} /* Assets.xcassets */,")
    a("\t\t\t);")
    a("\t\t\tpath = WorkoutMD;")
    a("\t\t\tsourceTree = \"<group>\";")
    a("\t\t};")

    def subgroup(group_key, folder_name, prefix):
        files = [f for f in SWIFT_FILES if f[2].startswith(f"WorkoutMD/{folder_name}/")]
        a(f"\t\t{U[group_key]} /* {folder_name} */ = {{")
        a("\t\t\tisa = PBXGroup;")
        a("\t\t\tchildren = (")
        for bf_key, fr_key, path, name in files:
            a(f"\t\t\t\t{U[fr_key]} /* {name} */,")
        a("\t\t\t);")
        a(f"\t\t\tpath = {folder_name};")
        a("\t\t\tsourceTree = \"<group>\";")
        a("\t\t};")

    subgroup("MODELS_GROUP",   "Models",   "BF_")
    subgroup("VIEWS_GROUP",    "Views",    "BF_")
    subgroup("SERVICES_GROUP", "Services", "BF_")
    subgroup("SETTINGS_GROUP", "Settings", "BF_")

    a("/* End PBXGroup section */")
    a("")

    # ---- PBXNativeTarget ----
    a("/* Begin PBXNativeTarget section */")
    a(f"\t\t{U['APP_TARGET']} /* WorkoutMD */ = {{")
    a("\t\t\tisa = PBXNativeTarget;")
    a(f"\t\t\tbuildConfigurationList = {U['TGT_CFG_LIST']} /* Build configuration list for PBXNativeTarget \"WorkoutMD\" */;")
    a("\t\t\tbuildPhases = (")
    a(f"\t\t\t\t{U['SOURCES_PHASE']} /* Sources */,")
    a(f"\t\t\t\t{U['FRAMEWORKS_PHASE']} /* Frameworks */,")
    a(f"\t\t\t\t{U['RESOURCES_PHASE']} /* Resources */,")
    a("\t\t\t);")
    a("\t\t\tbuildRules = (")
    a("\t\t\t);")
    a("\t\t\tdependencies = (")
    a("\t\t\t);")
    a("\t\t\tname = WorkoutMD;")
    a(f"\t\t\tproductName = WorkoutMD;")
    a(f"\t\t\tproductReference = {U['APP_PRODUCT']} /* WorkoutMD.app */;")
    a("\t\t\tproductType = \"com.apple.product-type.application\";")
    a("\t\t};")
    a("/* End PBXNativeTarget section */")
    a("")

    # ---- PBXProject ----
    a("/* Begin PBXProject section */")
    a(f"\t\t{U['PROJECT']} /* Project object */ = {{")
    a("\t\t\tisa = PBXProject;")
    a("\t\t\tattributes = {")
    a("\t\t\t\tBuildIndependentTargetsInParallel = 1;")
    a("\t\t\t\tLastSwiftUpdateCheck = 1600;")
    a("\t\t\t\tLastUpgradeCheck = 1600;")
    a("\t\t\t\tTargetAttributes = {")
    a(f"\t\t\t\t\t{U['APP_TARGET']} = {{")
    a("\t\t\t\t\t\tCreatedOnToolsVersion = 16.0;")
    a("\t\t\t\t\t};")
    a("\t\t\t\t};")
    a("\t\t\t};")
    a(f"\t\t\tbuildConfigurationList = {U['PROJ_CFG_LIST']} /* Build configuration list for PBXProject \"WorkoutMD\" */;")
    a("\t\t\tcompatibilityVersion = \"Xcode 14.0\";")
    a("\t\t\tdevelopmentRegion = en;")
    a("\t\t\thasScannedForEncodings = 0;")
    a("\t\t\tknownRegions = (")
    a("\t\t\t\ten,")
    a("\t\t\t\tBase,")
    a("\t\t\t);")
    a(f"\t\t\tmainGroup = {U['MAIN_GROUP']};")
    a(f"\t\t\tproductRefGroup = {U['PRODUCTS_GROUP']} /* Products */;")
    a("\t\t\tprojectDirPath = \"\";")
    a("\t\t\tprojectRoot = \"\";")
    a("\t\t\ttargets = (")
    a(f"\t\t\t\t{U['APP_TARGET']} /* WorkoutMD */,")
    a("\t\t\t);")
    a("\t\t};")
    a("/* End PBXProject section */")
    a("")

    # ---- PBXResourcesBuildPhase ----
    a("/* Begin PBXResourcesBuildPhase section */")
    a(f"\t\t{U['RESOURCES_PHASE']} /* Resources */ = {{")
    a("\t\t\tisa = PBXResourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    a(f"\t\t\t\t{U['BF_ASSETS']} /* Assets.xcassets in Resources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXResourcesBuildPhase section */")
    a("")

    # ---- PBXSourcesBuildPhase ----
    a("/* Begin PBXSourcesBuildPhase section */")
    a(f"\t\t{U['SOURCES_PHASE']} /* Sources */ = {{")
    a("\t\t\tisa = PBXSourcesBuildPhase;")
    a("\t\t\tbuildActionMask = 2147483647;")
    a("\t\t\tfiles = (")
    for bf_key, fr_key, path, name in SWIFT_FILES:
        a(f"\t\t\t\t{U[bf_key]} /* {name} in Sources */,")
    a("\t\t\t);")
    a("\t\t\trunOnlyForDeploymentPostprocessing = 0;")
    a("\t\t};")
    a("/* End PBXSourcesBuildPhase section */")
    a("")

    # ---- XCBuildConfiguration ----
    a("/* Begin XCBuildConfiguration section */")

    def build_cfg(uuid, name, is_debug, is_target):
        a(f"\t\t{uuid} /* {name} */ = {{")
        a("\t\t\tisa = XCBuildConfiguration;")
        a("\t\t\tbuildSettings = {")
        if is_target:
            a("\t\t\t\tASSET_CATALOG_COMPILER_OPTIONS = \"\";")
            a("\t\t\t\tASSTFRAMEWORK_SEARCH_PATHS = \"\";")
            a("\t\t\t\tCODE_SIGN_STYLE = Automatic;")
            a("\t\t\t\tCURRENT_PROJECT_VERSION = 1;")
            a("\t\t\t\tGENERATE_INFOPLIST_FILE = YES;")
            a("\t\t\t\tINFOPLIST_KEY_UIApplicationSceneManifest_Generation = YES;")
            a("\t\t\t\tINFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents = YES;")
            a("\t\t\t\tINFOPLIST_KEY_UILaunchScreen_Generation = YES;")
            a("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPad = \"UIInterfaceOrientationPortrait UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";")
            a("\t\t\t\tINFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone = \"UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight\";")
            a("\t\t\t\tLD_RUNPATH_SEARCH_PATHS = \"$(inherited) @executable_path/Frameworks\";")
            a("\t\t\t\tMARKETING_VERSION = 1.0;")
            a("\t\t\t\tPRODUCT_BUNDLE_IDENTIFIER = com.workoutmd.app;")
            a("\t\t\t\tPRODUCT_NAME = \"$(TARGET_NAME)\";")
            a("\t\t\t\tSWIFT_EMIT_LOC_STRINGS = YES;")
            a("\t\t\t\tSWIFT_VERSION = 5.0;")
            a("\t\t\t\tTARGETED_DEVICE_FAMILY = \"1,2\";")
        else:
            a("\t\t\t\tALWAYS_SEARCH_USER_PATHS = NO;")
            a("\t\t\t\tASSET_CATALOG_COMPILER_OPTIMIZATION = space;")
            a("\t\t\t\tCLANG_ANALYZER_NONNULL = YES;")
            a("\t\t\t\tCLANG_ANALYZER_NUMBER_OBJECT_CONVERSION = YES_AGGRESSIVE;")
            a("\t\t\t\tCLANG_CXX_LANGUAGE_STANDARD = \"gnu++20\";")
            a("\t\t\t\tCLANG_ENABLE_MODULES = YES;")
            a("\t\t\t\tCLANG_ENABLE_OBJC_ARC = YES;")
            a("\t\t\t\tCLANG_ENABLE_OBJC_WEAK = YES;")
            a("\t\t\t\tCLANG_WARN_BLOCK_CAPTURE_AUTORELEASING = YES;")
            a("\t\t\t\tCLANG_WARN_BOOL_CONVERSION = YES;")
            a("\t\t\t\tCLANG_WARN_COMMA = YES;")
            a("\t\t\t\tCLANG_WARN_CONSTANT_CONVERSION = YES;")
            a("\t\t\t\tCLANG_WARN_DEPRECATED_OBJC_IMPLEMENTATIONS = YES;")
            a("\t\t\t\tCLANG_WARN_DIRECT_OBJC_ISA_USAGE = YES_ERROR;")
            a("\t\t\t\tCLANG_WARN_DOCUMENTATION_COMMENTS = YES;")
            a("\t\t\t\tCLANG_WARN_EMPTY_BODY = YES;")
            a("\t\t\t\tCLANG_WARN_ENUM_CONVERSION = YES;")
            a("\t\t\t\tCLANG_WARN_INFINITE_RECURSION = YES;")
            a("\t\t\t\tCLANG_WARN_INT_CONVERSION = YES;")
            a("\t\t\t\tCLANG_WARN_NON_LITERAL_NULL_CONVERSION = YES;")
            a("\t\t\t\tCLANG_WARN_OBJC_IMPLICIT_RETAIN_CYCLES = YES;")
            a("\t\t\t\tCLANG_WARN_OBJC_LITERAL_CONVERSION = YES;")
            a("\t\t\t\tCLANG_WARN_OBJC_ROOT_CLASS = YES_ERROR;")
            a("\t\t\t\tCLANG_WARN_RANGE_LOOP_ANALYSIS = YES;")
            a("\t\t\t\tCLANG_WARN_STRICT_PROTOTYPES = YES;")
            a("\t\t\t\tCLANG_WARN_SUSPICIOUS_MOVE = YES;")
            a("\t\t\t\tCLANG_WARN_UNGUARDED_AVAILABILITY = YES_AGGRESSIVE;")
            a("\t\t\t\tCLANG_WARN_UNREACHABLE_CODE = YES;")
            a("\t\t\t\tCLANG_WARN__DUPLICATE_METHOD_DECL = YES;")
            a("\t\t\t\tCOPY_PHASE_STRIP = NO;")
            a("\t\t\t\tDEBUG_INFORMATION_FORMAT = " + ("dwarf;" if is_debug else "\"dwarf-with-dsym\";"))
            a("\t\t\t\tENABLE_NS_ASSERTIONS = " + ("YES;" if is_debug else "NO;"))
            a("\t\t\t\tENABLE_STRICT_OBJC_MSGSEND = YES;")
            a("\t\t\t\tGCC_C_LANGUAGE_STANDARD = gnu17;")
            a("\t\t\t\tGCC_DYNAMIC_NO_PIC = " + ("NO;" if is_debug else "NO;"))
            a("\t\t\t\tGCC_NO_COMMON_BLOCKS = YES;")
            a("\t\t\t\tGCC_OPTIMIZATION_LEVEL = " + ("0;" if is_debug else "s;"))
            a("\t\t\t\tGCC_PREPROCESSOR_DEFINITIONS = " + ("\"DEBUG=1 $(inherited)\";" if is_debug else "\"$(inherited)\";"))
            a("\t\t\t\tGCC_WARN_64_TO_32_BIT_CONVERSION = YES;")
            a("\t\t\t\tGCC_WARN_ABOUT_RETURN_TYPE = YES_ERROR;")
            a("\t\t\t\tGCC_WARN_UNDECLARED_SELECTOR = YES;")
            a("\t\t\t\tGCC_WARN_UNINITIALIZED_AUTOS = YES_AGGRESSIVE;")
            a("\t\t\t\tGCC_WARN_UNUSED_FUNCTION = YES;")
            a("\t\t\t\tGCC_WARN_UNUSED_VARIABLE = YES;")
            a("\t\t\t\tIPHONEOS_DEPLOYMENT_TARGET = 17.0;")
            a("\t\t\t\tMTL_ENABLE_DEBUG_INFO = " + ("INCLUDE_SOURCE;" if is_debug else "NO;"))
            a("\t\t\t\tMTL_FAST_MATH = YES;")
            a("\t\t\t\tONLY_ACTIVE_ARCH = " + ("YES;" if is_debug else "NO;"))
            a("\t\t\t\tSDKROOT = iphoneos;")
            a("\t\t\t\tSWIFT_ACTIVE_COMPILATION_CONDITIONS = " + ("\"DEBUG $(inherited)\";" if is_debug else "\"\";"))
            a("\t\t\t\tSWIFT_OPTIMIZATION_LEVEL = " + ("\"-Onone\";" if is_debug else "\"-O\";"))
            a("\t\t\t\tVALIDATE_PRODUCT = " + ("NO;" if is_debug else "YES;"))
        a("\t\t\t};")
        a(f"\t\t\tname = {name};")
        a("\t\t};")

    build_cfg(U["DEBUG_CFG_PROJ"],   "Debug",   is_debug=True,  is_target=False)
    build_cfg(U["RELEASE_CFG_PROJ"], "Release", is_debug=False, is_target=False)
    build_cfg(U["DEBUG_CFG_TGT"],    "Debug",   is_debug=True,  is_target=True)
    build_cfg(U["RELEASE_CFG_TGT"],  "Release", is_debug=False, is_target=True)

    a("/* End XCBuildConfiguration section */")
    a("")

    # ---- XCConfigurationList ----
    a("/* Begin XCConfigurationList section */")
    a(f"\t\t{U['PROJ_CFG_LIST']} /* Build configuration list for PBXProject \"WorkoutMD\" */ = {{")
    a("\t\t\tisa = XCConfigurationList;")
    a("\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{U['DEBUG_CFG_PROJ']} /* Debug */,")
    a(f"\t\t\t\t{U['RELEASE_CFG_PROJ']} /* Release */,")
    a("\t\t\t);")
    a("\t\t\tdefaultConfigurationIsVisible = 0;")
    a("\t\t\tdefaultConfigurationName = Release;")
    a("\t\t};")
    a(f"\t\t{U['TGT_CFG_LIST']} /* Build configuration list for PBXNativeTarget \"WorkoutMD\" */ = {{")
    a("\t\t\tisa = XCConfigurationList;")
    a("\t\t\tbuildConfigurations = (")
    a(f"\t\t\t\t{U['DEBUG_CFG_TGT']} /* Debug */,")
    a(f"\t\t\t\t{U['RELEASE_CFG_TGT']} /* Release */,")
    a("\t\t\t);")
    a("\t\t\tdefaultConfigurationIsVisible = 0;")
    a("\t\t\tdefaultConfigurationName = Release;")
    a("\t\t};")
    a("/* End XCConfigurationList section */")
    a("")

    # Close objects + root
    a("\t};")
    a(f"\trootObject = {U['PROJECT']} /* Project object */;")
    a("}")

    return "\n".join(lines)


if __name__ == "__main__":
    out_dir = os.path.join(os.path.dirname(__file__), "WorkoutMD.xcodeproj")
    os.makedirs(out_dir, exist_ok=True)
    pbx_path = os.path.join(out_dir, "project.pbxproj")
    with open(pbx_path, "w") as f:
        f.write(pbxproj())
    print(f"Written: {pbx_path}")

    # workspace contents
    ws_dir = os.path.join(out_dir, "project.xcworkspace")
    os.makedirs(ws_dir, exist_ok=True)
    ws_path = os.path.join(ws_dir, "contents.xcworkspacedata")
    ws_content = """<?xml version="1.0" encoding="UTF-8"?>
<Workspace
   version = "1.0">
   <FileRef
      location = "self:">
   </FileRef>
</Workspace>
"""
    with open(ws_path, "w") as f:
        f.write(ws_content)
    print(f"Written: {ws_path}")
