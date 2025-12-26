import NextLink, { type LinkProps } from 'next/link';

export function Link<RouteType>({
  children,
  href,
  ...props
}: LinkProps<RouteType>) {
  const shouldPrefetch = typeof href === 'string' && href.startsWith('/');

  return (
    <NextLink href={href} prefetch={shouldPrefetch} {...props}>
      {children}
    </NextLink>
  );
}
