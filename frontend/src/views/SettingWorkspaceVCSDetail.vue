<template>
  <div class="mt-4 space-y-4">
    <div class="flex justify-end">
      <div
        v-if="vcs.type == 'GITLAB_SELF_HOST'"
        class="flex flex-row items-center space-x-2"
      >
        <div class="textlabel whitespace-nowrap">
          {{
            $t(
              "version-control.setting.add-git-provider.gitlab-self-host-ce-ee"
            )
          }}
        </div>
        <img class="h-6 w-auto" src="../assets/gitlab-logo.svg" />
      </div>
      <div
        v-if="vcs.type == 'GITHUB_COM'"
        class="flex flex-row items-center space-x-2"
      >
        <div class="textlabel whitespace-nowrap">GitHub.com</div>
        <img class="h-6 w-auto" src="../assets/github-logo.svg" />
      </div>
    </div>

    <div>
      <label for="instanceurl" class="textlabel">
        {{ $t("common.instance") }} URL
      </label>
      <input
        id="instanceurl"
        name="instanceurl"
        type="text"
        class="textfield mt-1 w-full"
        disabled="true"
        :value="vcs.instanceUrl"
      />
    </div>

    <div>
      <label for="name" class="textlabel">
        {{
          $t("version-control.setting.add-git-provider.basic-info.display-name")
        }}
      </label>
      <p class="mt-1 textinfolabel">
        {{
          $t(
            "version-control.setting.add-git-provider.basic-info.display-name-label"
          )
        }}
      </p>
      <input
        id="name"
        v-model="state.name"
        name="name"
        type="text"
        class="textfield mt-1 w-full"
      />
    </div>

    <div>
      <label for="applicationid" class="textlabel">
        {{ $t("common.application") }} ID
      </label>
      <p class="mt-1 textinfolabel">
        <template v-if="vcs.type == 'GITLAB_SELF_HOST'">
          {{
            $t(
              "version-control.setting.git-provider.gitlab-application-id-label"
            )
          }}
          <a :href="adminApplicationUrl" target="_blank" class="normal-link">{{
            $t("version-control.setting.git-provider.view-in-gitlab")
          }}</a>
        </template>
        <template v-if="vcs.type == 'GITHUB_COM'">
          {{
            $t(
              "version-control.setting.git-provider.github-application-id-label"
            )
          }}
        </template>
      </p>
      <input
        id="applicationid"
        v-model="state.applicationId"
        name="applicationid"
        type="text"
        class="textfield mt-1 w-full"
      />
    </div>

    <div>
      <label for="secret" class="textlabel"> Secret </label>
      <p class="mt-1 textinfolabel">
        <template v-if="vcs.type == 'GITLAB_SELF_HOST'">
          {{ $t("version-control.setting.git-provider.secret-label-gitlab") }}
        </template>
        <template v-if="vcs.type == 'GITHUB_COM'">
          {{ $t("version-control.setting.git-provider.secret-label-github") }}
        </template>
      </p>
      <input
        id="secret"
        v-model="state.secret"
        name="secret"
        type="text"
        class="textfield mt-1 w-full"
        :placeholder="$t('common.sensitive-placeholder')"
      />
    </div>

    <div class="pt-4 flex border-t justify-between">
      <template v-if="repositoryList.length == 0">
        <BBButtonConfirm
          :style="'DELETE'"
          :button-text="'Delete this Git provider'"
          :ok-text="'Delete'"
          :confirm-title="`Delete Git provider '${vcs.name}'?`"
          :require-confirm="true"
          @confirm="deleteVCS"
        />
      </template>
      <template v-else>
        <div class="mt-1 textinfolabel">
          {{ $t("version-control.setting.git-provider.delete") }}
        </div>
      </template>
      <div>
        <button
          type="button"
          class="btn-normal py-2 px-4"
          @click.prevent="cancel"
        >
          {{ $t("common.cancel") }}
        </button>
        <button
          type="button"
          class="btn-primary ml-3 inline-flex justify-center py-2 px-4"
          :disabled="!allowUpdate"
          @click.prevent="doUpdate"
        >
          {{ $t("common.update") }}
        </button>
      </div>
    </div>
  </div>

  <div class="py-6">
    <div class="text-lg leading-6 font-medium text-main">
      {{ $t("repository.linked") + ` (${repositoryList.length})` }}
    </div>
    <div class="mt-4">
      <RepositoryTable :repository-list="repositoryList" />
    </div>
  </div>
</template>

<script lang="ts">
import {
  reactive,
  computed,
  watchEffect,
  onMounted,
  onUnmounted,
  defineComponent,
} from "vue";
import { useRouter } from "vue-router";
import RepositoryTable from "../components/RepositoryTable.vue";
import isEmpty from "lodash-es/isEmpty";
import { idFromSlug } from "../utils";
import {
  VCS,
  VCSPatch,
  openWindowForOAuth,
  OAuthWindowEventPayload,
  OAuthToken,
} from "../types";
import {
  pushNotification,
  useOAuthStore,
  useRepositoryStore,
  useVCSStore,
} from "@/store";

interface LocalState {
  name: string;
  applicationId: string;
  secret: string;
  oAuthResultCallback?: (token: OAuthToken | undefined) => void;
}

export default defineComponent({
  name: "SettingWorkspaceVCSDetail",
  components: { RepositoryTable },
  props: {
    vcsSlug: {
      required: true,
      type: String,
    },
  },
  setup(props) {
    const vcsStore = useVCSStore();
    const repositoryStore = useRepositoryStore();
    const router = useRouter();

    const vcs = computed((): VCS => {
      return vcsStore.getVCSById(idFromSlug(props.vcsSlug));
    });

    const state = reactive<LocalState>({
      name: vcs.value.name,
      applicationId: vcs.value.applicationId,
      secret: "",
    });

    onMounted(() => {
      window.addEventListener("bb.oauth.register-vcs", eventListener, false);
    });

    onUnmounted(() => {
      window.removeEventListener("bb.oauth.register-vcs", eventListener);
    });

    const eventListener = (event: Event) => {
      const payload = (event as CustomEvent).detail as OAuthWindowEventPayload;
      if (isEmpty(payload.error)) {
        if (
          vcs.value.type == "GITLAB_SELF_HOST" ||
          vcs.value.type == "GITHUB_COM"
        ) {
          useOAuthStore()
            .exchangeVCSTokenWithID({
              code: payload.code,
              vcsId: idFromSlug(props.vcsSlug),
              clientId: state.applicationId,
              clientSecret: state.secret,
            })
            .then((token: OAuthToken) => {
              state.oAuthResultCallback!(token);
            })
            .catch(() => {
              state.oAuthResultCallback!(undefined);
            });
        }
      } else {
        state.oAuthResultCallback!(undefined);
      }
    };

    const prepareRepositoryList = () => {
      repositoryStore.fetchRepositoryListByVCSId(vcs.value.id);
    };

    watchEffect(prepareRepositoryList);

    const adminApplicationUrl = computed(() => {
      if (vcs.value.type == "GITLAB_SELF_HOST") {
        return `${vcs.value.instanceUrl}/admin/applications`;
      }
      return "";
    });

    const repositoryList = computed(() =>
      repositoryStore.getRepositoryListByVCSId(vcs.value.id)
    );

    const allowUpdate = computed(() => {
      return (
        state.name != vcs.value.name ||
        state.applicationId != vcs.value.applicationId ||
        !isEmpty(state.secret)
      );
    });

    const doUpdate = () => {
      if (
        state.applicationId != vcs.value.applicationId ||
        !isEmpty(state.secret)
      ) {
        let authorizeUrl = `${vcs.value.instanceUrl}/oauth/authorize`;
        if (vcs.value.type == "GITHUB_COM") {
          authorizeUrl = `https://github.com/login/oauth/authorize`;
        }
        const newWindow = openWindowForOAuth(
          authorizeUrl,
          state.applicationId,
          "bb.oauth.register-vcs",
          vcs.value.type
        );
        if (newWindow) {
          state.oAuthResultCallback = (token: OAuthToken | undefined) => {
            if (token) {
              const vcsPatch: VCSPatch = {};
              if (state.name != vcs.value.name) {
                vcsPatch.name = state.name;
              }
              if (state.applicationId != vcs.value.applicationId) {
                vcsPatch.applicationId = state.applicationId;
              }
              if (!isEmpty(state.secret)) {
                vcsPatch.secret = state.secret;
              }
              vcsStore
                .patchVCS({
                  vcsId: vcs.value.id,
                  vcsPatch,
                })
                .then((vcs: VCS) => {
                  pushNotification({
                    module: "bytebase",
                    style: "SUCCESS",
                    title: `Successfully updated '${vcs.name}'`,
                  });
                });
            } else {
              // If the application ID mismatches, the OAuth workflow will stop early.
              // So the only possibility to reach here is we have a matching application ID, while
              // we failed to exchange a token, and it's likely we are requesting with a wrong secret.
              var description = "";
              if (vcs.value.type == "GITLAB_SELF_HOST") {
                description =
                  "Please make sure Secret matches the one from your GitLab instance Application.";
              } else if (vcs.value.type == "GITHUB_COM") {
                description =
                  "Please make sure Client secret matches the one from your GitHub.com Application.";
              }
              pushNotification({
                module: "bytebase",
                style: "CRITICAL",
                title: `Failed to update '${vcs.value.name}'`,
                description: description,
              });
            }
          };
        }
      } else if (state.name != vcs.value.name) {
        const vcsPatch: VCSPatch = {
          name: state.name,
        };
        vcsStore
          .patchVCS({
            vcsId: vcs.value.id,
            vcsPatch,
          })
          .then((updatedVCS: VCS) => {
            pushNotification({
              module: "bytebase",
              style: "SUCCESS",
              title: `Successfully updated '${updatedVCS.name}'`,
            });
          });
      }
    };

    const cancel = () => {
      router.push({
        name: "setting.workspace.version-control",
      });
    };

    const deleteVCS = () => {
      const name = vcs.value.name;
      vcsStore.deleteVCSById(vcs.value.id).then(() => {
        pushNotification({
          module: "bytebase",
          style: "SUCCESS",
          title: `Successfully deleted '${name}'`,
        });
        router.push({
          name: "setting.workspace.version-control",
        });
      });
    };

    return {
      state,
      vcs,
      repositoryList,
      adminApplicationUrl,
      allowUpdate,
      doUpdate,
      cancel,
      deleteVCS,
    };
  },
});
</script>
