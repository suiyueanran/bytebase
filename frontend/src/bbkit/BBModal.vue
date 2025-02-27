<template>
  <teleport to="#bb-modal-stack">
    <div class="fixed inset-0 bg-transparent" :style="style" />
    <div
      v-bind="$attrs"
      class="bb-modal"
      :style="style"
      :data-bb-modal-id="id"
      :data-bb-modal-index="index"
      :data-bb-modal-active="active"
    >
      <div class="relative -mt-4 -ml-4 flex items-center justify-between">
        <div class="ml-4 text-xl text-main">
          <slot name="title"><component :is="renderTitle" /></slot>
          <component :is="renderSubtitle" />
        </div>
        <button
          v-if="showClose"
          class="text-control-light"
          aria-label="close"
          @click.prevent="close"
        >
          <span class="sr-only">Close</span>
          <!-- Heroicons name: x -->
          <heroicons-solid:x class="w-6 h-6" />
        </button>
      </div>
      <div class="modal-container">
        <slot />
      </div>
    </div>
  </teleport>
</template>

<script lang="ts">
import {
  computed,
  defineComponent,
  h,
  inject,
  onBeforeMount,
  onMounted,
  onUnmounted,
  provide,
  ref,
  Ref,
  RenderFunction,
  VNode,
} from "vue";
import { useModalStack } from "./BBModalStack.vue";

type Overrides = {
  title: string | RenderFunction | undefined;
  subtitle: string | RenderFunction | undefined;
};
type BBModalContext = {
  overrides: Ref<Overrides>;
};
const BB_MODAL_CONTEXT = Symbol("bb.modal.context");

export default defineComponent({
  name: "BBModal",
  props: {
    title: {
      default: "",
      type: String,
    },
    subtitle: {
      default: "",
      type: String,
    },
    showClose: {
      type: Boolean,
      default: true,
    },
    escClosable: {
      type: Boolean,
      default: true,
    },
  },
  emits: ["close"],
  setup(props, { emit }) {
    const { stack, id, index, active } = useModalStack();

    const style = computed(() => ({
      "z-index": 40 + index.value, // "40 + " because the container in BBModalStack is z-40
    }));

    const overrides = ref<Overrides>({
      title: undefined,
      subtitle: undefined,
    });

    const close = () => {
      emit("close");
    };

    const escHandler = (e: KeyboardEvent) => {
      if (e.code == "Escape") {
        e.preventDefault();
        e.stopPropagation();

        if (!props.escClosable) {
          return;
        }
        if (!active.value) {
          // only to close the topmost modal when pressing ESC
          return;
        }
        close();
      }
    };

    onMounted(() => {
      document.addEventListener("keydown", escHandler);
    });

    onUnmounted(() => {
      document.removeEventListener("keydown", escHandler);
    });

    provide<BBModalContext>(BB_MODAL_CONTEXT, {
      overrides,
    });

    const renderTitle = () => {
      if (typeof overrides.value.title === "function") {
        return overrides.value.title();
      }
      if (typeof overrides.value.title === "string") {
        return overrides.value.title;
      }
      return props.title;
    };

    const renderSubtitle = () => {
      if (typeof overrides.value.subtitle === "function") {
        return overrides.value.subtitle();
      }
      if (typeof overrides.value.subtitle === "string") {
        return overrides.value.subtitle;
      }
      if (props.subtitle) {
        return h(
          "div",
          {
            class: "text-sm text-control whitespace-nowrap",
          },
          [h("span", { class: "inline-block" }, props.subtitle)]
        );
      }
      return null;
    };

    return {
      style,
      close,
      stack,
      id,
      index,
      active,
      overrides,
      renderTitle,
      renderSubtitle,
    };
  },
});

const useBBModalContext = () => inject<BBModalContext>(BB_MODAL_CONTEXT);

export const useOverrideTitle = (
  title: string | RenderFunction | undefined
) => {
  const context = useBBModalContext();
  let originalTitle: string | RenderFunction | undefined = undefined;
  onBeforeMount(() => {
    if (context) {
      originalTitle = context.overrides.value.title;
      context.overrides.value.title = title;
    }
  });
  onUnmounted(() => {
    if (context) {
      context.overrides.value.title = originalTitle;
    }
  });
};

export const useOverrideSubtitle = (
  subtitle: string | RenderFunction | undefined
) => {
  const context = useBBModalContext();
  let originalSubtitle: string | RenderFunction | undefined = undefined;
  onMounted(() => {
    if (context) {
      originalSubtitle = context.overrides.value.subtitle;
      context.overrides.value.subtitle = subtitle;
    }
  });
  onUnmounted(() => {
    if (context) {
      context.overrides.value.subtitle = originalSubtitle;
    }
  });
};
</script>

<style scoped>
.bb-modal {
  @apply absolute m-auto w-full max-w-max bg-white shadow-lg rounded-lg p-8 flex space-y-6 divide-y divide-block-border pointer-events-auto;
  @apply flex-col;

  max-height: calc(100vh - 80px);
}

.modal-container {
  @apply px-0.5 pt-4 max-h-screen overflow-auto w-full;

  margin-top: 0.5rem !important;
}
</style>
