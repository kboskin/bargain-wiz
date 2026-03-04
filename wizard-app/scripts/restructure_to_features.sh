#!/usr/bin/env bash
# Restructure lib/ to features with data/domain/presentation per feature.
# Does NOT touch lib/core or lib/l10n.

set -e
cd "$(dirname "$0")/.."
LIB=lib
F=features

# Create feature directories (data, domain, presentation for each)
for feature in shared auth onboarding feedback conversation express_dealmaker lines_that_land subscription paywall home start_with_text; do
  mkdir -p "$LIB/$F/$feature/data/datasources" "$LIB/$F/$feature/data/mappers" "$LIB/$F/$feature/data/models/remote_config" "$LIB/$F/$feature/data/network" "$LIB/$F/$feature/data/repositories"
  mkdir -p "$LIB/$F/$feature/domain/entities" "$LIB/$F/$feature/domain/repositories"
  mkdir -p "$LIB/$F/$feature/presentation/bloc" "$LIB/$F/$feature/presentation/pages" "$LIB/$F/$feature/presentation/widgets"
done

# --- SHARED ---
mv "$LIB/data/models/multilocale_text.dart" "$LIB/$F/shared/data/models/" 2>/dev/null || true
mv "$LIB/data/models/multilocale_text.g.dart" "$LIB/$F/shared/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/validatable_entity.dart" "$LIB/$F/shared/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/json_helpers.dart" "$LIB/$F/shared/data/models/" 2>/dev/null || true
mv "$LIB/data/network/network_info_impl.dart" "$LIB/$F/shared/data/network/" 2>/dev/null || true
mv "$LIB/domain/repositories/repository.dart" "$LIB/$F/shared/domain/repositories/" 2>/dev/null || true
mv "$LIB/data/repositories/repository_impl.dart" "$LIB/$F/shared/data/repositories/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/button_config.dart" "$LIB/$F/shared/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/button_config.g.dart" "$LIB/$F/shared/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/presentation/bloc/base_bloc.dart" "$LIB/$F/shared/presentation/bloc/" 2>/dev/null || true

# --- AUTH ---
mv "$LIB/presentation/bloc/auth"/* "$LIB/$F/auth/presentation/bloc/" 2>/dev/null || true
mv "$LIB/presentation/pages/auth"/* "$LIB/$F/auth/presentation/pages/" 2>/dev/null || true
rmdir "$LIB/presentation/bloc/auth" "$LIB/presentation/pages/auth" 2>/dev/null || true

# --- FEEDBACK ---
mv "$LIB/domain/entities/feedback_form_config.dart" "$LIB/$F/feedback/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/entities/feedback_form_field.dart" "$LIB/$F/feedback/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/repositories/feedback_repository.dart" "$LIB/$F/feedback/domain/repositories/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/feedback_form_config_model.dart" "$LIB/$F/feedback/data/models/" 2>/dev/null || true
mv "$LIB/data/datasources/feedback_remote_datasource.dart" "$LIB/$F/feedback/data/datasources/" 2>/dev/null || true
mv "$LIB/data/datasources/feedback_remote_datasource_impl.dart" "$LIB/$F/feedback/data/datasources/" 2>/dev/null || true
mv "$LIB/data/repositories/feedback_repository_impl.dart" "$LIB/$F/feedback/data/repositories/" 2>/dev/null || true
mv "$LIB/data/mappers/feedback_form_mapper.dart" "$LIB/$F/feedback/data/mappers/" 2>/dev/null || true
mv "$LIB/presentation/bloc/feedback"/* "$LIB/$F/feedback/presentation/bloc/" 2>/dev/null || true
mv "$LIB/presentation/pages/feedback"/* "$LIB/$F/feedback/presentation/pages/" 2>/dev/null || true
rmdir "$LIB/presentation/bloc/feedback" "$LIB/presentation/pages/feedback" 2>/dev/null || true

# --- CONVERSATION ---
mv "$LIB/domain/entities/conversation.dart" "$LIB/$F/conversation/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/repositories/conversation_repository.dart" "$LIB/$F/conversation/domain/repositories/" 2>/dev/null || true
mv "$LIB/data/models/conversation_model.dart" "$LIB/$F/conversation/data/models/" 2>/dev/null || true
mv "$LIB/data/models/conversation_model.g.dart" "$LIB/$F/conversation/data/models/" 2>/dev/null || true
mv "$LIB/data/models/pro_deal_closer_message_model.dart" "$LIB/$F/conversation/data/models/" 2>/dev/null || true
mv "$LIB/data/models/pro_deal_closer_message_model.g.dart" "$LIB/$F/conversation/data/models/" 2>/dev/null || true
mv "$LIB/data/datasources/conversation_local_datasource.dart" "$LIB/$F/conversation/data/datasources/" 2>/dev/null || true
mv "$LIB/data/repositories/conversation_repository_impl.dart" "$LIB/$F/conversation/data/repositories/" 2>/dev/null || true
mv "$LIB/data/mappers/conversation_mapper.dart" "$LIB/$F/conversation/data/mappers/" 2>/dev/null || true
mv "$LIB/data/mappers/conversation_type_mapper.dart" "$LIB/$F/conversation/data/mappers/" 2>/dev/null || true

# --- EXPRESS DEALMAKER ---
mv "$LIB/domain/entities/deal_reply.dart" "$LIB/$F/express_dealmaker/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/entities/upload_screenshot_result.dart" "$LIB/$F/express_dealmaker/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/repositories/express_dealmaker_repository.dart" "$LIB/$F/express_dealmaker/domain/repositories/" 2>/dev/null || true
mv "$LIB/data/datasources/express_dealmaker_remote_datasource.dart" "$LIB/$F/express_dealmaker/data/datasources/" 2>/dev/null || true
mv "$LIB/data/repositories/express_dealmaker_repository_impl.dart" "$LIB/$F/express_dealmaker/data/repositories/" 2>/dev/null || true
mv "$LIB/data/mappers/express_dealmaker_mapper.dart" "$LIB/$F/express_dealmaker/data/mappers/" 2>/dev/null || true
mv "$LIB/presentation/pages/home/simple_mode_section.dart" "$LIB/$F/express_dealmaker/presentation/pages/" 2>/dev/null || true
mv "$LIB/presentation/pages/home/screenshot_upload_item.dart" "$LIB/$F/express_dealmaker/presentation/pages/" 2>/dev/null || true

# --- LINES THAT LAND ---
mv "$LIB/domain/entities/lines_that_land_category.dart" "$LIB/$F/lines_that_land/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/entities/lines_that_land_tip.dart" "$LIB/$F/lines_that_land/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/repositories/lines_that_land_repository.dart" "$LIB/$F/lines_that_land/domain/repositories/" 2>/dev/null || true
mv "$LIB/data/models/lines_that_land_category_model.dart" "$LIB/$F/lines_that_land/data/models/" 2>/dev/null || true
mv "$LIB/data/models/lines_that_land_tip_model.dart" "$LIB/$F/lines_that_land/data/models/" 2>/dev/null || true
mv "$LIB/data/datasources/lines_that_land_remote_datasource.dart" "$LIB/$F/lines_that_land/data/datasources/" 2>/dev/null || true
mv "$LIB/data/repositories/lines_that_land_repository_impl.dart" "$LIB/$F/lines_that_land/data/repositories/" 2>/dev/null || true
mv "$LIB/data/mappers/lines_that_land_mapper.dart" "$LIB/$F/lines_that_land/data/mappers/" 2>/dev/null || true
mv "$LIB/presentation/bloc/lines_that_land"/* "$LIB/$F/lines_that_land/presentation/bloc/" 2>/dev/null || true
mv "$LIB/presentation/widgets/lines_that_land_sheet.dart" "$LIB/$F/lines_that_land/presentation/widgets/" 2>/dev/null || true
rmdir "$LIB/presentation/bloc/lines_that_land" 2>/dev/null || true

# --- SUBSCRIPTION ---
mv "$LIB/domain/entities/subscription_product.dart" "$LIB/$F/subscription/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/entities/subscription_status.dart" "$LIB/$F/subscription/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/entities/subscription_tier.dart" "$LIB/$F/subscription/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/repositories/subscription_repository.dart" "$LIB/$F/subscription/domain/repositories/" 2>/dev/null || true
mv "$LIB/data/models/subscription_model.dart" "$LIB/$F/subscription/data/models/" 2>/dev/null || true
mv "$LIB/data/models/subscription_model.g.dart" "$LIB/$F/subscription/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/subscription_config.dart" "$LIB/$F/subscription/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/subscription_config.g.dart" "$LIB/$F/subscription/data/models/" 2>/dev/null || true
mv "$LIB/data/datasources/subscription_in_memory_datasource.dart" "$LIB/$F/subscription/data/datasources/" 2>/dev/null || true
mv "$LIB/data/repositories/subscription_repository_impl.dart" "$LIB/$F/subscription/data/repositories/" 2>/dev/null || true
mv "$LIB/presentation/bloc/subscription"/* "$LIB/$F/subscription/presentation/bloc/" 2>/dev/null || true
rmdir "$LIB/presentation/bloc/subscription" 2>/dev/null || true

# --- ONBOARDING ---
mv "$LIB/domain/entities/onboarding_data_entity.dart" "$LIB/$F/onboarding/domain/entities/" 2>/dev/null || true
mv "$LIB/domain/repositories/onboarding_repository.dart" "$LIB/$F/onboarding/domain/repositories/" 2>/dev/null || true
mv "$LIB/data/models/onboarding_data.dart" "$LIB/$F/onboarding/data/models/" 2>/dev/null || true
mv "$LIB/data/models/onboarding_data.g.dart" "$LIB/$F/onboarding/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/onboarding_model.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/onboarding_model.g.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/onboarding_config.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/onboarding_config.g.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/onboarding_screen_config.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/onboarding_screen_config.g.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/welcome_screen_config.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/welcome_screen_config.g.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/upload_progress_screen_config.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/upload_progress_screen_config.g.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/gradient_background_config.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/gradient_background_config.g.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/highlight_words_config.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/highlight_words_config.g.dart" "$LIB/$F/onboarding/data/models/remote_config/" 2>/dev/null || true
mv "$LIB/data/datasources/onboarding_local_datasource.dart" "$LIB/$F/onboarding/data/datasources/" 2>/dev/null || true
mv "$LIB/data/repositories/onboarding_repository_impl.dart" "$LIB/$F/onboarding/data/repositories/" 2>/dev/null || true
mv "$LIB/data/mappers/onboarding_data_mapper.dart" "$LIB/$F/onboarding/data/mappers/" 2>/dev/null || true
mv "$LIB/data/mappers/onboarding_screen_type_mapper.dart" "$LIB/$F/onboarding/data/mappers/" 2>/dev/null || true
mv "$LIB/presentation/bloc/onboarding"/* "$LIB/$F/onboarding/presentation/bloc/" 2>/dev/null || true
mv "$LIB/presentation/pages/onboarding"/* "$LIB/$F/onboarding/presentation/pages/" 2>/dev/null || true
mv "$LIB/presentation/pages/onboarding/widgets"/* "$LIB/$F/onboarding/presentation/widgets/" 2>/dev/null || true
rmdir "$LIB/presentation/bloc/onboarding" "$LIB/presentation/pages/onboarding/widgets" "$LIB/presentation/pages/onboarding" 2>/dev/null || true

# --- PAYWALL ---
mv "$LIB/data/models/remote_config/paywall_config.dart" "$LIB/$F/paywall/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/paywall_config.g.dart" "$LIB/$F/paywall/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/paywall_layout.dart" "$LIB/$F/paywall/data/models/" 2>/dev/null || true
mv "$LIB/presentation/pages/paywall"/* "$LIB/$F/paywall/presentation/pages/" 2>/dev/null || true
# paywall_screen_widget is in onboarding/widgets - move from onboarding feature after onboarding move
# (already moved with onboarding above to onboarding/presentation/widgets)

# --- HOME ---
mv "$LIB/data/models/remote_config/main_page_config.dart" "$LIB/$F/home/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/main_page_config.g.dart" "$LIB/$F/home/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/share_config.dart" "$LIB/$F/home/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/share_config.g.dart" "$LIB/$F/home/data/models/" 2>/dev/null || true
mv "$LIB/data/models/remote_config/rate_us_modal_config.dart" "$LIB/$F/home/data/models/" 2>/dev/null || true
mv "$LIB/presentation/pages/home"/* "$LIB/$F/home/presentation/pages/" 2>/dev/null || true
mv "$LIB/presentation/widgets/glass_two_choice_modal.dart" "$LIB/$F/home/presentation/widgets/" 2>/dev/null || true
rmdir "$LIB/presentation/pages/home" 2>/dev/null || true

# --- START_WITH_TEXT ---
mv "$LIB/presentation/pages/start_with_text"/* "$LIB/$F/start_with_text/presentation/pages/" 2>/dev/null || true
rmdir "$LIB/presentation/pages/start_with_text" 2>/dev/null || true

# Remove empty legacy dirs
for dir in "$LIB/data/datasources" "$LIB/data/mappers" "$LIB/data/repositories" "$LIB/data/models/remote_config" "$LIB/data/models" "$LIB/data/network" "$LIB/domain/entities" "$LIB/domain/repositories" "$LIB/presentation/bloc" "$LIB/presentation/pages" "$LIB/presentation/widgets"; do
  rmdir "$dir" 2>/dev/null || true
done
rmdir "$LIB/data" "$LIB/domain" "$LIB/presentation" 2>/dev/null || true

echo "Restructure script completed. You must update imports in all files and core/di, core/routing."
