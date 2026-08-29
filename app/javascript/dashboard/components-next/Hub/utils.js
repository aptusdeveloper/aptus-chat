export const localDateISO = date => {
  const pad = value => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};

export const presetDayRange = days => {
  const today = new Date();
  const from = new Date(today);
  from.setDate(from.getDate() - (days - 1));
  return { from: localDateISO(from), to: localDateISO(today) };
};

export const formatNumber = value => Number(value || 0).toLocaleString('pt-BR');

export const formatCurrency = (value, currency = 'BRL') =>
  Number(value || 0).toLocaleString('pt-BR', {
    style: 'currency',
    currency,
  });

export const formatDate = value => {
  if (!value) return '-';
  const date = new Date(`${value}T00:00:00`);
  return date.toLocaleDateString('pt-BR');
};

export const formatShortDate = value => {
  if (!value) return '';
  const date = new Date(`${value}T00:00:00`);
  return date.toLocaleDateString('pt-BR', { day: '2-digit', month: '2-digit' });
};

export const formatWeekday = value => {
  if (!value) return '';
  const date = new Date(`${value}T00:00:00`);
  const label = date.toLocaleDateString('pt-BR', { weekday: 'short' });
  return label.charAt(0).toUpperCase() + label.slice(1).replace('.', '');
};

export const formatHour = value => {
  if (!value) return '';
  const date = new Date(value);
  return date.toLocaleTimeString('pt-BR', {
    hour: '2-digit',
    minute: '2-digit',
  });
};

export const formatMonthLabel = month => {
  if (!month) return '-';
  const date = new Date(`${month}-01T00:00:00`);
  return date.toLocaleDateString('pt-BR', { month: 'long', year: 'numeric' });
};

export const paymentStatusLabel = status => {
  const labels = {
    paid: 'Pago',
    open: 'Em aberto',
    pending: 'Pendente',
    overdue: 'Vencido',
  };

  return labels[status] || 'Pendente';
};

export const paymentStatusClass = status => {
  const classes = {
    paid: 'bg-n-teal-3 text-n-teal-11',
    open: 'bg-n-slate-3 text-n-slate-11',
    pending: 'bg-n-amber-3 text-n-amber-11',
    overdue: 'bg-n-ruby-3 text-n-ruby-11',
  };

  return classes[status] || classes.pending;
};

export const hubErrorMessage = error =>
  error?.response?.data?.error || 'Nao foi possivel carregar o Hub agora.';
