#
# Copyright (C) 2011 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# DEX2OAT defined in build/core/config.mk
DEX2OATD := $(HOST_OUT_EXECUTABLES)/dex2oatd$(HOST_EXECUTABLE_SUFFIX)

LIBART_COMPILER := $(HOST_OUT_SHARED_LIBRARIES)/libart-compiler$(HOST_SHLIB_SUFFIX)
LIBARTD_COMPILER := $(HOST_OUT_SHARED_LIBRARIES)/libartd-compiler$(HOST_SHLIB_SUFFIX)

# TODO: for now, override with debug version for better error reporting
DEX2OAT := $(DEX2OATD)
LIBART_COMPILER := $(LIBARTD_COMPILER)

# By default, do not run rerun dex2oat if the tool changes.
# Comment out the | to force dex2oat to rerun on after all changes.
DEX2OAT_DEPENDENCY := |
DEX2OAT_DEPENDENCY += $(DEX2OAT)
DEX2OAT_DEPENDENCY += $(LIBART_COMPILER)

OATDUMP := $(HOST_OUT_EXECUTABLES)/oatdump$(HOST_EXECUTABLE_SUFFIX)
OATDUMPD := $(HOST_OUT_EXECUTABLES)/oatdumpd$(HOST_EXECUTABLE_SUFFIX)
# TODO: for now, override with debug version for better error reporting
OATDUMP := $(OATDUMPD)

PRELOADED_CLASSES := frameworks/base/preloaded-classes

########################################################################
# A smaller libcore only oat file
TARGET_CORE_JARS := core-libart conscrypt okhttp core-junit bouncycastle
HOST_CORE_JARS := $(addsuffix -hostdex,$(TARGET_CORE_JARS))

HOST_CORE_DEX_LOCATIONS   := $(foreach jar,$(HOST_CORE_JARS),  $(HOST_OUT_JAVA_LIBRARIES)/$(jar).jar)
TARGET_CORE_DEX_LOCATIONS := $(foreach jar,$(TARGET_CORE_JARS),/$(DEXPREOPT_BOOT_JAR_DIR)/$(jar).jar)

HOST_CORE_DEX_FILES   := $(foreach jar,$(HOST_CORE_JARS),  $(call intermediates-dir-for,JAVA_LIBRARIES,$(jar),t,COMMON)/javalib.jar)
TARGET_CORE_DEX_FILES := $(foreach jar,$(TARGET_CORE_JARS),$(call intermediates-dir-for,JAVA_LIBRARIES,$(jar), ,COMMON)/javalib.jar)

HOST_CORE_OAT := $(HOST_OUT_JAVA_LIBRARIES)/core.oat
TARGET_CORE_OAT := $(ART_TEST_DIR)/core.oat

HOST_CORE_OAT_OUT := $(HOST_OUT_JAVA_LIBRARIES)/core.oat
TARGET_CORE_OAT_OUT := $(ART_TEST_OUT)/core.oat

HOST_CORE_IMG_OUT := $(HOST_OUT_JAVA_LIBRARIES)/core.art
TARGET_CORE_IMG_OUT := $(ART_TEST_OUT)/core.art

# Use dex2oat debug version for better error reporting
$(HOST_CORE_IMG_OUT): $(HOST_CORE_DEX_FILES) $(DEX2OATD_DEPENDENCY)
	@echo "host dex2oat: $@ ($?)"
	@mkdir -p $(dir $@)
	$(hide) $(DEX2OATD) --runtime-arg -Xms16m --runtime-arg -Xmx16m --image-classes=$(PRELOADED_CLASSES) $(addprefix \
		--dex-file=,$(HOST_CORE_DEX_FILES)) $(addprefix --dex-location=,$(HOST_CORE_DEX_LOCATIONS)) --oat-file=$(HOST_CORE_OAT_OUT) \
		--oat-location=$(HOST_CORE_OAT) --image=$(HOST_CORE_IMG_OUT) --base=$(LIBART_IMG_HOST_BASE_ADDRESS) \
		--instruction-set=$(ART_HOST_ARCH) --host --android-root=$(HOST_OUT)

$(HOST_CORE_OAT_OUT): $(HOST_CORE_IMG_OUT)
$(TARGET_CORE_IMG_OUT): $(TARGET_CORE_DEX_FILES) $(DEX2OAT_DEPENDENCY)
	@echo "target dex2oat: $@ ($?)"
	@mkdir -p $(dir $@)
	$(hide) $(DEX2OAT) $(PARALLEL_ART_COMPILE_JOBS) --runtime-arg -Xms16m --runtime-arg -Xmx16m --image-classes=$(PRELOADED_CLASSES) $(addprefix --dex-file=,$(TARGET_CORE_DEX_FILES)) $(addprefix --dex-location=,$(TARGET_CORE_DEX_LOCATIONS)) --oat-file=$(TARGET_CORE_OAT_OUT) --oat-location=$(TARGET_CORE_OAT) --image=$(TARGET_CORE_IMG_OUT) --base=$(IMG_TARGET_BASE_ADDRESS) --instruction-set=$(TARGET_ARCH) --host-prefix=$(PRODUCT_OUT) --android-root=$(PRODUCT_OUT)/system

define create-oat-target-targets
$$($(1)TARGET_CORE_IMG_OUT): $$($(1)TARGET_CORE_DEX_FILES) $$(DEX2OATD_DEPENDENCY)
	@echo "target dex2oat: $$@ ($$?)"
	@mkdir -p $$(dir $$@)
	$$(hide) $$(DEX2OATD) --runtime-arg -Xms16m --runtime-arg -Xmx16m --image-classes=$$(PRELOADED_CLASSES) $$(addprefix \
		--dex-file=,$$(TARGET_CORE_DEX_FILES)) $$(addprefix --dex-location=,$$(TARGET_CORE_DEX_LOCATIONS)) --oat-file=$$($(1)TARGET_CORE_OAT_OUT) \
		--oat-location=$$($(1)TARGET_CORE_OAT) --image=$$($(1)TARGET_CORE_IMG_OUT) --base=$$(LIBART_IMG_TARGET_BASE_ADDRESS) \
		--instruction-set=$$($(1)TARGET_ARCH) --instruction-set-features=$$(TARGET_INSTRUCTION_SET_FEATURES) --android-root=$$(PRODUCT_OUT)/system

$$($(1)TARGET_CORE_OAT_OUT): $$($(1)TARGET_CORE_IMG_OUT)
endef

ifdef TARGET_2ND_ARCH
$(eval $(call create-oat-target-targets,2ND_))
endif
$(eval $(call create-oat-target-targets,))

$(TARGET_CORE_OAT_OUT): $(TARGET_CORE_IMG_OUT)

ifeq ($(ART_BUILD_HOST),true)
include $(CLEAR_VARS)
LOCAL_MODULE := core.art-host
LOCAL_MODULE_TAGS := optional
LOCAL_ADDITIONAL_DEPENDENCIES := art/build/Android.common.mk
LOCAL_ADDITIONAL_DEPENDENCIES += art/build/Android.oat.mk
LOCAL_ADDITIONAL_DEPENDENCIES += $(HOST_CORE_IMG_OUT)
include $(BUILD_PHONY_PACKAGE)
endif # ART_BUILD_HOST

# If we aren't building the host toolchain, skip building the target core.art.
ifeq ($(WITH_HOST_DALVIK),true)
ifeq ($(ART_BUILD_TARGET),true)
include $(CLEAR_VARS)
LOCAL_MODULE := core.art
LOCAL_MODULE_TAGS := optional
LOCAL_ADDITIONAL_DEPENDENCIES := art/build/Android.common.mk
LOCAL_ADDITIONAL_DEPENDENCIES += art/build/Android.oat.mk
LOCAL_ADDITIONAL_DEPENDENCIES += $(TARGET_CORE_IMG_OUT)
include $(BUILD_PHONY_PACKAGE)
endif # ART_BUILD_TARGET
endif # WITH_HOST_DALVIK
