export const localDateISO = date => {
  const pad = value => String(value).padStart(2, '0');
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`;
};

export const currentMonthRange = () => {
  const today = new Date();
  return {
    from: localDateISO(new Date(today.getFullYear(), today.getMonth(), 1)),
    to: localDateISO(today),
  };
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

export const paymentStatusLabel = status => {
  const labels = {
    paid: 'Pago',
    pending: 'Pendente',
    overdue: 'Vencido',
  };

  return labels[status] || 'Pendente';
};

export const paymentStatusClass = status => {
  const classes = {
    paid: 'bg-n-teal-3 text-n-teal-11',
    pending: 'bg-n-amber-3 text-n-amber-11',
    overdue: 'bg-n-ruby-3 text-n-ruby-11',
  };

  return classes[status] || classes.pending;
};

export const hubErrorMessage = error =>
  error?.response?.data?.error || 'Nao foi possivel carregar o Hub agora.';
