<script lang="ts">
  export let size = 20;
  export let width: number = size;
  export let height: number = size;
  const originalViewBoxWidth = 2500;
  const targetViewBoxSize = 20;
  const scale: number = targetViewBoxSize / originalViewBoxWidth;
</script>

<svg
  {width}
  {height}
  viewBox={`0 0 ${targetViewBoxSize} ${targetViewBoxSize}`}
  xmlns="http://www.w3.org/2000/svg"
  preserveAspectRatio="xMinYMin meet">
  <g transform={`scale(${scale})`}>
    <circle cx="1250" cy="1250" r="1250" style="fill-rule:evenodd;clip-rule:evenodd;fill:#627EEA;" />

    <path style="fill:#FFFFFF;fill-opacity:0.602;" d="M1288.91,312.5v692.97l585.7,261.72L1288.91,312.5z" />
    <path style="fill:#FFFFFF;" d="M1288.91,312.5l-585.78,954.69l585.78-261.72L1288.91,312.5z" />
    <path style="fill:#FFFFFF;fill-opacity:0.602;" d="M1288.91,1716.25v470.86L1875,1376.25L1288.91,1716.25z" />
    <path style="fill:#FFFFFF;" d="M1288.91,2187.11v-470.94l-585.78-339.92L1288.91,2187.11z" />
    <path style="fill:#FFFFFF;fill-opacity:0.2;" d="M1288.91,1607.27l585.7-340.08l-585.7-261.56V1607.27z" />
    <path style="fill:#FFFFFF;fill-opacity:0.602;" d="M703.12,1267.19l585.78,340.08v-601.64L703.12,1267.19z" />
  </g>
</svg>
