// Constants
export const DEFAULT_LANGUAGE = 'en';
export const DEFAULT_CATEGORY = 'UTILITY';
export const COMPONENT_TYPES = {
  HEADER: 'HEADER',
  BODY: 'BODY',
  BUTTONS: 'BUTTONS',
  CAROUSEL: 'CAROUSEL',
};
export const MEDIA_FORMATS = ['IMAGE', 'VIDEO', 'DOCUMENT'];

const PRIVATE_IPV4_PATTERNS = [
  /^10\./,
  /^127\./,
  /^169\.254\./,
  /^192\.168\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
];

export const isPublicHttpsMediaUrl = value => {
  try {
    const url = new URL(value);
    const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, '');

    if (url.protocol !== 'https:' || !hostname) return false;
    if (hostname === 'localhost' || hostname.endsWith('.localhost')) {
      return false;
    }
    if (!hostname.includes('.') && !hostname.includes(':')) return false;
    if (
      hostname === '::1' ||
      hostname.startsWith('fc') ||
      hostname.startsWith('fd')
    ) {
      return false;
    }
    if (/^fe[89ab]/.test(hostname)) {
      return false;
    }

    return !PRIVATE_IPV4_PATTERNS.some(pattern => pattern.test(hostname));
  } catch {
    return false;
  }
};

export const findComponentByType = (template, type) =>
  template.components?.find(component => component.type === type);

export const processVariable = str => {
  return str.replace(/{{|}}/g, '');
};

export const allKeysRequired = value => {
  const keys = Object.keys(value);
  return keys.every(key => value[key]);
};

export const replaceTemplateVariables = (templateText, processedParams) => {
  return templateText.replace(/{{([^}]+)}}/g, (match, variable) => {
    const variableKey = processVariable(variable);
    return processedParams.body?.[variableKey] || `{{${variable}}}`;
  });
};

// Carousel cards all share the same header format and button layout (Meta
// requirement) — only the reference (first) card needs to be inspected to
// know the "shape" every card's parameter slots must follow.
const carouselCardShape = carouselComponent => {
  const referenceCard = carouselComponent?.cards?.[0];
  const headerComponent = referenceCard?.components?.find(
    component => component.type === COMPONENT_TYPES.HEADER
  );
  const buttonsComponent = referenceCard?.components?.find(
    component => component.type === COMPONENT_TYPES.BUTTONS
  );

  return {
    cardCount: carouselComponent?.cards?.length || 0,
    hasMediaHeader: MEDIA_FORMATS.includes(headerComponent?.format),
    headerFormat: headerComponent?.format?.toLowerCase() || '',
    buttons: buttonsComponent?.buttons || [],
  };
};

// Builds the parameter slots for one card's buttons, preserving the button's
// original index (as a sparse array) so it lines up with the button `index`
// the backend expects when only some buttons need a dynamic parameter.
const buildCardButtonSlots = buttons => {
  const slots = [];
  buttons.forEach((button, index) => {
    if (button.type === 'QUICK_REPLY') {
      slots[index] = { type: 'quick_reply', parameter: '' };
    } else if (
      button.type === 'URL' &&
      button.url &&
      button.url.includes('{{')
    ) {
      slots[index] = { type: 'url', parameter: '' };
    } else if (button.type === 'COPY_CODE') {
      slots[index] = { type: 'copy_code', parameter: '' };
    }
  });
  return slots;
};

export const buildCarouselParameters = carouselComponent => {
  const { cardCount, hasMediaHeader, headerFormat, buttons } =
    carouselCardShape(carouselComponent);

  return Array.from({ length: cardCount }, () => {
    const card = {};

    // Carousel card headers only support image/video (unlike the top-level
    // header, which also supports document) — no media_name/filename field.
    if (hasMediaHeader) {
      card.header = { media_url: '', media_type: headerFormat };
    }

    const buttonSlots = buildCardButtonSlots(buttons);
    if (buttonSlots.length) card.buttons = buttonSlots;

    return card;
  });
};

export const buildTemplateParameters = (template, hasMediaHeaderValue) => {
  const allVariables = {};

  const bodyComponent = findComponentByType(template, COMPONENT_TYPES.BODY);
  const headerComponent = findComponentByType(template, COMPONENT_TYPES.HEADER);

  if (!bodyComponent) return allVariables;

  const templateString = bodyComponent.text;

  // Process body variables
  const matchedVariables = templateString.match(/{{([^}]+)}}/g);
  if (matchedVariables) {
    allVariables.body = {};
    matchedVariables.forEach(variable => {
      const key = processVariable(variable);
      allVariables.body[key] = '';
    });
  }

  if (hasMediaHeaderValue) {
    if (!allVariables.header) allVariables.header = {};
    allVariables.header.media_url = '';
    allVariables.header.media_type = headerComponent.format.toLowerCase();

    // For document templates, include media_name field for filename support
    if (headerComponent.format.toLowerCase() === 'document') {
      allVariables.header.media_name = '';
    }
  }

  // Process button variables
  const buttonComponents = template.components.filter(
    component => component.type === COMPONENT_TYPES.BUTTONS
  );

  buttonComponents.forEach(buttonComponent => {
    if (buttonComponent.buttons) {
      buttonComponent.buttons.forEach((button, index) => {
        // Handle URL buttons with variables
        if (button.type === 'URL' && button.url && button.url.includes('{{')) {
          const buttonVars = button.url.match(/{{([^}]+)}}/g) || [];
          if (buttonVars.length > 0) {
            if (!allVariables.buttons) allVariables.buttons = [];
            allVariables.buttons[index] = {
              type: 'url',
              parameter: '',
              url: button.url,
              variables: buttonVars.map(v => processVariable(v)),
            };
          }
        }

        // Handle copy code buttons
        if (button.type === 'COPY_CODE') {
          if (!allVariables.buttons) allVariables.buttons = [];
          allVariables.buttons[index] = {
            type: 'copy_code',
            parameter: '',
          };
        }
      });
    }
  });

  const carouselComponent = findComponentByType(
    template,
    COMPONENT_TYPES.CAROUSEL
  );
  if (carouselComponent) {
    allVariables.cards = buildCarouselParameters(carouselComponent);
  }

  return allVariables;
};
